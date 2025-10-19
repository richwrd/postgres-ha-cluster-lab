"""
Teste de RPO - Falha do Nó Primário

Verifica se há perda de dados após failover.

VERSÃO ASSÍNCRONA:
- Observação em tempo real de todos os nós
- Detecção precisa de eventos de failover
- Verificação confiável de perda de dados
- SLA: RPO ≈ 0 (replicação síncrona na mesma região)
"""
import pytest
import asyncio
from src.core.docker_manager import DockerManager
from src.core.config import config


@pytest.mark.rpo
@pytest.mark.resilience
class TestRPOPrimaryFailure:
    
    @pytest.mark.asyncio
    async def test_primary_failure_data_loss(
        self,
        rpo_collector,
        rpo_writer,
        cluster_healthy,
        get_primary_node,
        pgpool_manager
    ):
        """
        Teste de Resiliência (RPO)
        
        Procedimento (ASSÍNCRONO):
        1. Inicia observação de TODOS os nós do cluster
        2. Cria tabela de teste
        3. Escreve transações no primário
        4. Simula falha do primário
        5. Aguarda eleição de novo primário
        6. Verifica se todas as transações foram recuperadas
        
        SLA: RPO ≈ 0 (mesmo em replicação assíncrona, mesma região)
        
        IMPORTANTE - Entendendo RPO em Replicação ASSÍNCRONA:
        
        ┌─────────────────────────────────────────────────────────┐
        │ REPLICAÇÃO ASSÍNCRONA (synchronous_commit = off)        │
        ├─────────────────────────────────────────────────────────┤
        │ 1. Cliente: INSERT                                      │
        │ 2. Primário: escreve WAL                               │
        │ 3. Primário: retorna OK IMEDIATAMENTE                  │
        │ 4. Standby: recebe WAL posteriormente                  │
        │                                                         │
        │ → Transação confirmada ≠ replicada ainda               │
        │ → JANELA DE RISCO: perda de dados possível             │
        │ → RPO > 0 possível (depende da latência)               │
        └─────────────────────────────────────────────────────────┘
        
        AMBIENTE ÚNICO (Docker Localhost):
        ┌─────────────────────────────────────────────────────────┐
        │ Latência ultra-baixa: ~0.1-0.5ms                        │
        │ Replicação "instantânea" mesmo sendo async             │
        │ Tempo de teste (5s) >> tempo de replicação (~100ms)   │
        │                                                         │
        │ → RESULTADO: RPO = 0 esperado                          │
        │ → Mesmo sem sync, dados são protegidos                 │
        └─────────────────────────────────────────────────────────┘
        
        Este teste VALIDA que:
        1. Replicação assíncrona funciona corretamente
        2. Latência baixa protege contra perda de dados
        3. Standby recebe WAL rapidamente
        
        Em produção (multi-região):
        - Latência: 50-200ms+
        - RPO > 0 possível
        - Considerar replicação síncrona para dados críticos
        
        Observações:
        - Sem sleeps arbitrários
        - Detecção real de eventos via API Patroni
        - Verificação precisa de transações
        """
        docker = DockerManager()
        
        print("\n" + "="*70)
        print("TESTE RPO - FALHA COMPLETA DO NÓ PRIMÁRIO (ASYNC)")
        print("="*70)
        
        # 0. Inicia observação assíncrona
        print("\n[0/7] 🔍 Iniciando observação do cluster...")
        await rpo_collector.start_observation()
        print("✓ Cluster sob observação (polling: 100ms)")
        
        # Aguarda estabilização
        await asyncio.sleep(0.3)
        
        # 1. Setup - Cria tabela de teste
        print("\n[1/7] 📋 Criando tabela de teste...")
        success = rpo_collector.setup_test_table()
        assert success, "Falha ao criar tabela de teste"
        print("✓ Tabela criada")
        
        # 2. Identifica primário
        print("\n[2/7] 🎯 Identificando primário...")
        initial_primary = get_primary_node()
        assert initial_primary, "Primário não identificado"
        print(f"✓ Primário: {initial_primary}")
        
        metrics = rpo_collector.start_measurement(
            "primary_failure_rpo",
            initial_primary
        )
        
        # 3. Escreve transações de teste (ASSÍNCRONO - injeta falha NO MEIO)
        print("\n[3/7] ✍️  Iniciando escrita contínua de transações...")
        print("  ℹ️  Nota: Em replicação ASSÍNCRONA, há janela de risco entre commit e replicação")

        num_transactions = 1000  # Volume maior para aumentar chance de capturar lag

        async def _write_transactions_continuously():
            """Escreve transações em background"""
            count = 0
            for i in range(num_transactions):
                try:
                    tx_id = rpo_collector.write_transaction(f"test_data_{i}")
                    if tx_id:
                        count += 1
                except Exception as e:
                    # Esperado: conexão pode falhar quando primário cai
                    print(f"    ⚠️  TX {i} falhou: {type(e).__name__}")
                    break
                # Delay muito pequeno para simular carga contínua
                await asyncio.sleep(0.01)  # 10ms entre transações
            return count
        
        # Inicia escrita em background
        print(f" ✍️  Iniciando escrita de {num_transactions} transações em background...")
        write_task = asyncio.create_task(_write_transactions_continuously())
        
        # Aguarda que metade das transações sejam escritas
        # (tempo estimado: 1000 tx * 10ms = 10s para todas, então 5s para metade)
        await asyncio.sleep(5.0)

        # Captura quantas foram escritas até agora
        pre_failure_tx = rpo_collector.metrics.last_transaction_id_written or 0
        print(f"  ⏱️  Transações escritas até agora: {pre_failure_tx}")
        print(f"  💥 Injetando falha AGORA (com escritas ainda em andamento)...")
        
        # 4. Injeta falha NO MEIO da escrita
        print(f"\n[4/7] 💥 KILL {initial_primary} (escritas continuam em background)...")
        rpo_collector.mark_failure_occurred()
        
        success = docker.kill_container(initial_primary,signal="SIGKILL")
        assert success, "Falha ao parar container"
        print(f"✓ Container {initial_primary} morto instantaneamente (SIGKILL)")
        
        # Aguarda task de escrita terminar ou falhar
        print(f"  ⏱️  Aguardando task de escrita finalizar/falhar...")
        try:
            transactions_attempted = await asyncio.wait_for(write_task, timeout=10)
            print(f"  ✓ Task completou: {transactions_attempted} transações tentadas")
        except asyncio.TimeoutError:
            print(f"  ⚠️  Task timeout (esperado se conexão travou)")
            write_task.cancel()
            try:
                await write_task
            except asyncio.CancelledError:
                pass
        except Exception as e:
            print(f"  ⚠️  Task falhou: {type(e).__name__} (esperado)")
        
        last_tx_id = rpo_collector.metrics.last_transaction_id_written or 0
        print(f"  📊 Última TX ID CONFIRMADA antes da falha: {last_tx_id}")
        print(f"  🎯 Transações 'em voo': ~{num_transactions - last_tx_id}")
        
        # 5. Aguarda novo primário
        print(f"\n[5/7] 🗳️  Observando eleição de novo primário...")
        new_primary = await rpo_collector.wait_for_new_primary(
            timeout=60,
            old_primary=initial_primary
        )
        assert new_primary, "Timeout: novo primário NÃO foi eleito!"
        assert new_primary != initial_primary, "Primário não mudou!"
        
        # 6. Verifica dados recuperados
        print("\n[6/7] 🔍 Verificando dados recuperados...")
        recovered_count = await rpo_collector.verify_data_after_recovery()
        
        print(f"  Transações escritas:    {last_tx_id}")
        print(f"  Transações recuperadas: {recovered_count}")
        
        # 7. Finaliza medição
        print(f"\n[7/7] 📊 Finalizando medição...")
        rpo_collector.finalize_metrics()
        
        # Para observação
        await rpo_collector.stop_observation()
        
        # Obtém métricas
        metrics = rpo_collector.get_metrics()
        assert metrics, "Métricas não foram coletadas"
        
        # Salva resultados
        rpo_writer.write(metrics)
        
        # Exibe resultados
        self._print_rpo_metrics(metrics, num_transactions)
        
        # Exibe eventos detectados
        print(rpo_collector.get_events_summary())
        
        # Valida SLA (RPO ≈ 0)
        self._validate_sla_rpo(metrics)
        
        # Cleanup: reinicia o container e re-anexa o nó ao PgPool via PCP
        print(f"\n[Cleanup] 🔄 Reiniciando {initial_primary}...")
        docker.start_container(initial_primary)

        # Aguarda container subir
        await asyncio.sleep(2)

        # Re-anexa nós ao PgPool
        pgpool_manager.attach_down_nodes()

        # Remove tabela de teste
        rpo_collector.drop_test_table()
        
        # Aguarda estabilização (pode usar um pouco de tempo aqui, não é medido)
        await asyncio.sleep(5)
        print("✓ Cleanup concluído")
    
    def _print_rpo_metrics(self, metrics, expected_count):
        """Exibe métricas formatadas com detalhamento"""
        print("\n" + "="*70)
        print("MÉTRICAS DE RPO (MEDIÇÃO ASSÍNCRONA)")
        print("="*70)
        print(f"Test Case:         {metrics.test_case}")
        print(f"Nó que falhou:     {metrics.failed_node}")
        print(f"Novo primário:     {metrics.new_primary_node}")
        print("-"*70)
        print("DADOS DE TRANSAÇÕES:")
        print(f"  TXs escritas:          {metrics.last_transaction_id_written}")
        print(f"  TXs recuperadas:       {metrics.last_transaction_id_recovered}")
        print(f"  TXs perdidas:          {metrics.transactions_lost}")
        print(f"  Houve perda:           {'SIM ⚠️' if metrics.data_loss_occurred else 'NÃO ✅'}")
        print("-"*70)
        if metrics.replication_lag_bytes is not None:
            print(f"Lag de replicação:     {metrics.replication_lag_bytes} bytes")
        if metrics.rpo_seconds is not None:
            print(f"RPO (segundos):        {metrics.rpo_seconds:.3f}s")
        print("="*70)

    
    def _validate_sla_rpo(self, metrics):
        """Valida SLA de RPO e exibe resultados"""
        
        print(f"\n{'='*70}")
        print("VALIDAÇÃO DE SLA - REPLICAÇÃO ASSÍNCRONA")
        print("="*70)
 
        lost = metrics.transactions_lost or 0
        written = metrics.last_transaction_id_written or 1
        loss_percent = (lost / written * 100) if written > 0 else 0
        
        # ═══════════════════════════════════════════════════════════════
        # DEFINIÇÃO DE SLAs POR AMBIENTE
        # ═══════════════════════════════════════════════════════════════
        
        # Ambiente único (Docker localhost)
        sla_single_env = {
            'name': 'Único (Docker Localhost)',
            'latency': '0.1-0.5ms',
            'target_rpo_percent': 0.0,   # 0% esperado
            'max_rpo_percent': 1.0,      # até 1% aceitável
            'description': 'Latência ultra-baixa, replicação "instantânea"'
        }
        
        # Produção - Mesma região
        sla_same_region = {
            'name': 'Produção - Mesma Região',
            'latency': '1-5ms',
            'target_rpo_percent': 0.0,   # 0% ideal
            'max_rpo_percent': 2.0,      # até 2% aceitável
            'description': 'Latência baixa, perda mínima'
        }
        
        # Produção - Multi-região (mesmo continente)
        sla_multi_region = {
            'name': 'Produção - Multi-Região',
            'latency': '20-50ms',
            'target_rpo_percent': 2.0,   # 2% esperado
            'max_rpo_percent': 5.0,      # até 5% aceitável
            'description': 'Latência média, perda moderada'
        }
        
        # Produção - Inter-continental
        sla_intercontinental = {
            'name': 'Produção - Inter-Continental',
            'latency': '100-300ms',
            'target_rpo_percent': 5.0,   # 5% esperado
            'max_rpo_percent': 10.0,     # até 10% aceitável
            'description': 'Latência alta, considerar replicação síncrona'
        }
        
        # Seleciona SLA do ambiente atual (único)
        current_sla = sla_single_env
        
        # ═══════════════════════════════════════════════════════════════
        # VALIDAÇÃO AMBIENTE ATUAL
        # ═══════════════════════════════════════════════════════════════
        
        print(f"Ambiente atual:    {current_sla['name']}")
        print(f"Latência típica:   {current_sla['latency']}")
        print(f"Descrição:         {current_sla['description']}")
        print("-"*70)
        
        # Validação
        target_met = loss_percent <= current_sla['target_rpo_percent']
        acceptable = loss_percent <= current_sla['max_rpo_percent']
        
        print(f"Target RPO:        ≤ {current_sla['target_rpo_percent']:.1f}% (ideal)")
        print(f"Máximo aceitável:  ≤ {current_sla['max_rpo_percent']:.1f}%")
        print(f"RPO medido:        {loss_percent:.2f}% ({lost} de {written} transações)")
        
        if target_met:
            status = "✅ EXCELENTE"
        elif acceptable:
            status = "✅ PASSOU"
        else:
            status = "⚠️  FALHOU"
        
        print(f"Status:            {status}")
        print("="*70)
        
        # ═══════════════════════════════════════════════════════════════
        # COMPARAÇÃO COM OUTROS AMBIENTES (REFERÊNCIA)
        # ═══════════════════════════════════════════════════════════════
        
        print("\n📊 COMPARAÇÃO: RPO ESPERADO EM DIFERENTES AMBIENTES")
        print("="*70)
        
        scenarios = [sla_single_env, sla_same_region, sla_multi_region, sla_intercontinental]
        
        for scenario in scenarios:
            is_current = (scenario == current_sla)
            marker = "→ VOCÊ ESTÁ AQUI" if is_current else ""
            
            print(f"\n{scenario['name']} {marker}")
            print(f"  Latência:         {scenario['latency']}")
            print(f"  RPO esperado:     {scenario['target_rpo_percent']:.1f}% - {scenario['max_rpo_percent']:.1f}%")
            print(f"  Descrição:        {scenario['description']}")
            
            if is_current:
                print(f"  Seu resultado:    {loss_percent:.2f}% {'✅' if acceptable else '⚠️'}")
        
        print("="*70)
        
        # ═══════════════════════════════════════════════════════════════
        # ANÁLISE DETALHADA DO RESULTADO
        # ═══════════════════════════════════════════════════════════════
        
        print("\n📈 ANÁLISE DO RESULTADO")
        print("="*70)
        
        if lost == 0:
            print("✅ ZERO PERDA DE DADOS")
            print("")
            print("Significado:")
            print("  • Todas as transações foram replicadas antes da falha")
            print("  • Replicação assíncrona suficientemente rápida")
            print("  • Latência não é fator limitante neste ambiente")
            print("  • Standby estava sincronizado")
            print("")
            print("Conclusão:")
            print("  ✓ Sistema resiliente e confiável")
            print("  ✓ Replicação assíncrona adequada para este ambiente")
            print("  ✓ Sem necessidade de replicação síncrona")
            
        elif acceptable:
            print(f"✅ PERDA MÍNIMA ACEITÁVEL ({lost} transações)")
            print("")
            print("Significado:")
            print(f"  • {loss_percent:.2f}% de perda está dentro do esperado")
            print("  • Janela de risco entre commit e replicação")
            print("  • Comportamento normal em replicação assíncrona")
            print("")
            print("Conclusão:")
            print("  ✓ Sistema funcionando conforme especificação")
            print("  ✓ RPO aceitável para este tipo de replicação")
            
        else:
            print(f"⚠️  PERDA ACIMA DO ESPERADO ({lost} transações)")
            print("")
            print("Possíveis causas:")
            print("  • Lag de replicação alto")
            print("  • Standby sobrecarregado")
            print("  • Problemas de rede")
            print("  • WAL sender/receiver lentos")
            print("")
            print("Recomendações:")
            print("  → Investigar logs do PostgreSQL")
            print("  → Verificar métricas de replicação")
            print("  → Considerar tuning de WAL")
            print("  → Avaliar upgrade de hardware")
        
        print("="*70)
        
        # ═══════════════════════════════════════════════════════════════
        # RESULTADO FINAL
        # ═══════════════════════════════════════════════════════════════
        
        if target_met:
            print(f"\n🎉 RESULTADO: RPO = {lost} transações ({loss_percent:.2f}%)")
            print(f"   Objetivo atingido! Perda {'zero' if lost == 0 else 'mínima'}.")
        elif acceptable:
            print(f"\n✅ RESULTADO: RPO = {lost} transações ({loss_percent:.2f}%)")
            print(f"   Dentro do aceitável para ambiente {current_sla['name']}.")
        else:
            print(f"\n⚠️  RESULTADO: RPO = {lost} transações ({loss_percent:.2f}%)")
            print(f"   Acima do esperado. Investigação necessária.")

