"""
Teste de RTO - Manutenção Programada (Switchover Controlado)

Simula manutenção programada onde a transição de liderança é iniciada
proativamente através do comando patronictl switchover. O objetivo é medir
o tempo de indisponibilidade em uma troca controlada.

VERSÃO ASSÍNCRONA:
- Observação em tempo real de todos os nós
- Detecção precisa de eventos
- Medição de RTO em cenário de manutenção planejada
"""
import pytest
import asyncio
from src.core.patroni_manager import PatroniManager
from src.core.pgpool_manager import PgPoolManager
from src.core.config import config


@pytest.mark.rto
@pytest.mark.resilience
@pytest.mark.switchover
class TestRTOPlannedSwitchover:
    
    @pytest.mark.asyncio
    async def test_planned_maintenance_switchover(
        self,
        rto_collector,
        rto_writer,
        cluster_healthy,
        get_primary_node,
        pgpool_manager
    ):
        """
        Teste de Resiliência (RTO) - Manutenção Programada
        
        Procedimento (ASSÍNCRONO):
        1. Inicia observação de TODOS os nós do cluster
        2. Identifica nó primário atual
        3. Executa switchover controlado (patronictl switchover)
        4. Observa eleição de novo primário
        5. Verifica disponibilidade do serviço
        
        Objetivo: Medir downtime em manutenção planejada
        Expectativa: RTO < 10s (switchover deve ser mais rápido que failover)
        
        Observações:
        - Switchover é controlado, não é falha abrupta
        - Patroni coordena a transição de forma ordenada
        - Menos overhead que failover completo
        """
        patroni = PatroniManager()
        pgpool = PgPoolManager()
        
        print("\n" + "="*70)
        print("TESTE RTO - MANUTENÇÃO PROGRAMADA (SWITCHOVER CONTROLADO)")
        print("="*70)
        
        # Prepara PgPool (anexa nós DOWN se houver)
        attach_result = pgpool.attach_down_nodes()
        print("\nPreparando PgPool...")
        if attach_result["nodes_attached"]:
            print(f"✓ Nós anexados ao PgPool: {attach_result['nodes_attached']}")
        if attach_result["nodes_failed"]:
            print(f"⚠️  Falha ao anexar nós: {attach_result['nodes_failed']}")
        
        # 0. Inicia observação assíncrona
        print("\n[0/5] 🔍 Iniciando observação do cluster...")
        await rto_collector.start_observation_switchover()
        print("✓ Cluster sob observação (polling: 100ms)")
        
        # 1. Identifica primário
        print("\n[1/5] 🎯 Identificando nó primário...")
        initial_primary = get_primary_node()
        assert initial_primary, "Primário não identificado"
        print(f"✓ Primário atual: {initial_primary}")
        
        # 2. Prepara medição e executa switchover
        print(f"\n[2/5] 🔄 Executando switchover controlado...")
        
        metrics = rto_collector.start_measurement(
            "planned_maintenance_switchover",
            initial_primary,
            "switchover"
        )
        
        # Executa switchover (sem target, Patroni escolhe melhor réplica)
        success = patroni.switchover(force=True)
        assert success, "Falha ao executar switchover"
        print(f"✓ Switchover iniciado em {initial_primary}")
    
        # 3. Aguarda novo primário
        print(f"\n[3/6] 🗳️  Observando eleição...")
        new_primary = await rto_collector.wait_for_new_primary(
            timeout=30,
            old_primary=initial_primary
        )
        assert new_primary, "Timeout: novo primário NÃO foi eleito!"
        print(f"✓ Target eleito corretamente: {new_primary}")
        
        # 3. Aguarda SERVIÇO disponível
        print(f"\n[3/5] 🔌 Verificando disponibilidade do serviço...")
        service_ok = await rto_collector.wait_for_service_available(timeout=30)
        assert service_ok, "Serviço PostgreSQL NÃO ficou disponível!"
        print(f"✓ Serviço disponível")
        
        # 5. Finaliza medição
        print(f"\n[5/5] 📊 Finalizando medição...")
        rto_collector.finalize_metrics()
        
        # Para observação
        await rto_collector.stop_observation()
        
        # Obtém métricas
        metrics = rto_collector.get_metrics()
        assert metrics, "Métricas não foram coletadas"
        
        # Salva resultados
        rto_writer.write(metrics)
        
        # Exibe resultados
        self._print_rto_metrics(metrics)
        
        # Exibe eventos detectados
        print(rto_collector.get_events_summary())

        # Valida SLA (switchover deve ser mais rápido)
        self._validate_sla_rto(metrics)
        
        # Aguarda estabilização
        await asyncio.sleep(3)
        print("\n✓ Teste concluído")
    
    def _print_rto_metrics(self, metrics):
        """Exibe métricas formatadas para switchover controlado"""
        print("\n" + "="*70)
        print("MÉTRICAS DE RTO - SWITCHOVER CONTROLADO")
        print("="*70)
        print(f"Test Case:         {metrics.test_case}")
        print(f"Tipo de operação:  {metrics.failure_type}")
        print(f"Primário original: {metrics.failed_node}")
        print(f"Novo primário:     {metrics.new_primary_node}")
        print("-"*70)
        print("FASES DO SWITCHOVER:")
        print(f"  1. Início:       {metrics.failure_injected_at}")
        print(f"  2. Novo primário eleito: {metrics.new_primary_elected_at}")
        print(f"  3. Serviço disponível:   {metrics.service_restored_at}")
        print("-"*70)
        print(f"DOWNTIME TOTAL:    {metrics.total_rto:8.3f}s")
        print("="*70)

    def _validate_sla_rto(self, metrics):
        """Valida SLA específico para switchover (mais rigoroso)"""
        
        print(f"\n{'='*70}")
        print("VALIDAÇÃO DE SLA - MANUTENÇÃO PROGRAMADA")
        print("="*70)
        
        # Switchover deve ser mais rápido que failover
        sla_target = 10.0  # segundos (mais rigoroso que failover)
        sla_passed = metrics.total_rto < sla_target
        
        print(f"Target RTO:        < {sla_target}s (switchover controlado)")
        print(f"RTO Medido:        {metrics.total_rto:.3f}s")
        print(f"Status:            {'✅ PASSOU' if sla_passed else '⚠️  EXCEDEU'}")
        
        if sla_passed:
            margin = sla_target - metrics.total_rto
            print(f"Margem:            {margin:.3f}s ({margin/sla_target*100:.1f}%)")
        else:
            exceeded = metrics.total_rto - sla_target
            print(f"Excedeu:           +{exceeded:.3f}s ({exceeded/sla_target*100:.1f}%)")
        
        print("="*70)
        
        # Apenas exibe resultado, não falha o teste
        if sla_passed:
            print(f"\n✅ RTO dentro do target: {metrics.total_rto:.3f}s (target: <{sla_target}s)")
        else:
            print(f"\n⚠️  RTO acima do target: {metrics.total_rto:.3f}s (target: <{sla_target}s)")
            print("   → Teste continuou para coleta de dados")
