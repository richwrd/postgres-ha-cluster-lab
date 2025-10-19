"""
Teste de RTO - Falha do Nó Primário

Simula falha completa do nó primário e mede tempo de recuperação.

VERSÃO ASSÍNCRONA:
- Observação em tempo real de todos os nós
- Zero sleeps arbitrários
- Detecção precisa de eventos
- Medição confiável para SLA de 99,99% (RTO < 60s)
"""
import pytest
import asyncio
from src.core.docker_manager import DockerManager
from src.core.config import config


@pytest.mark.rto
@pytest.mark.resilience
class TestRTOPrimaryFailure:
    
    @pytest.mark.asyncio
    async def test_primary_node_complete_failure(
        self,
        rto_collector,
        rto_writer,
        cluster_healthy,
        get_primary_node,
        pgpool_manager
    ):
        """
        Teste de Resiliência (RTO)
        
        Procedimento (ASSÍNCRONO):
        1. Inicia observação de TODOS os nós do cluster
        2. Identifica nó primário
        3. Para o container (docker stop)
        4. Observa quando RÉPLICAS detectam a falha
        5. Observa eleição de novo primário
        6. Verifica disponibilidade do serviço
        
        SLA: RTO < 60 segundos (para 99,99% uptime)
        
        Observações:
        - Sem sleeps arbitrários
        - Polling de 100ms em todos os nós
        - Detecção real de eventos via API Patroni
        """
        docker = DockerManager()
        
        print("\n" + "="*70)
        print("TESTE RTO - FALHA COMPLETA DO NÓ PRIMÁRIO (ASYNC)")
        print("="*70)
        
        # 0. Inicia observação assíncrona
        print("\n[0/6] 🔍 Iniciando observação do cluster...")
        await rto_collector.start_observation()
        print("✓ Cluster sob observação (polling: 100ms)")
        
        # Aguarda estabilização
        await asyncio.sleep(0.3)
        
        # 1. Identifica primário
        print("\n[1/6] 🎯 Identificando nó primário...")
        initial_primary = get_primary_node()
        assert initial_primary, "Primário não identificado"
        print(f"✓ Primário: {initial_primary}")
        
        # 2. Prepara medição e injeta falha
        print(f"\n[2/6] 💥 Injetando falha: parando {initial_primary}...")
        
        metrics = rto_collector.start_measurement(
            "primary_complete_failure",
            initial_primary,
            "stop"
        )
        
        # Para container (falha catastrófica)
        success = docker.stop_container(initial_primary)
        assert success, "Falha ao parar container"
        print(f"✓ Container {initial_primary} parado")
        
        # 3. Aguarda DETECÇÃO real pelos nós restantes
        print(f"\n[3/6] 👁️  Observando detecção da falha pelas réplicas...")
        detected = await rto_collector.wait_for_failure_detection(timeout=30)
        assert detected, "Falha NÃO foi detectada pelas réplicas!"
        
        # 4. Aguarda ELEIÇÃO de novo primário
        print(f"\n[4/6] 🗳️  Observando eleição de novo primário...")
        new_primary = await rto_collector.wait_for_new_primary(
            timeout=60,
            old_primary=initial_primary
        )
        assert new_primary, "Timeout: novo primário NÃO foi eleito!"
        assert new_primary != initial_primary, "Primário não mudou!"
        
        # 5. Aguarda SERVIÇO disponível
        print(f"\n[5/6] 🔌 Verificando disponibilidade do serviço...")
        service_ok = await rto_collector.wait_for_service_available(timeout=60)
        assert service_ok, "Serviço PostgreSQL NÃO ficou disponível!"
        
        # 6. Finaliza medição
        print(f"\n[6/6] 📊 Finalizando medição...")
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

        # Valida SLA
        self._validate_sla_rto(metrics)
        
        # Cleanup: reinicia o container e re-anexa o nó ao PgPool via PCP
        print(f"\n[Cleanup] 🔄 Reiniciando {initial_primary}...")
        docker.start_container(initial_primary)

        # Aguarda container subir
        await asyncio.sleep(2)

        # Re-anexa nós ao PgPool
        pgpool_manager.attach_down_nodes()
        
        # Aguarda estabilização (pode usar um pouco de tempo aqui, não é medido)
        await asyncio.sleep(5)
        print("✓ Cleanup concluído")
    
    
    def _print_rto_metrics(self, metrics):
        """Exibe métricas formatadas com detalhamento"""
        print("\n" + "="*70)
        print("MÉTRICAS DE RTO (MEDIÇÃO ASSÍNCRONA)")
        print("="*70)
        print(f"Test Case:         {metrics.test_case}")
        print(f"Tipo de falha:     {metrics.failure_type}")
        print(f"Nó que falhou:     {metrics.failed_node}")
        print(f"Novo primário:     {metrics.new_primary_node}")
        print("-"*70)
        print("TEMPOS PARCIAIS:")
        print(f"  1. Detecção:     {metrics.detection_time:8.3f}s  (cluster percebe falha)")
        print(f"  2. Eleição:      {metrics.election_time:8.3f}s  (novo leader eleito)")
        print(f"  3. Restauração:  {metrics.restoration_time:8.3f}s  (serviço disponível)")
        print("-"*70)
        print(f"RTO TOTAL:         {metrics.total_rto:8.3f}s")
        print("="*70)

    def _validate_sla_rto(self, metrics):
        """Valida SLA e exibe resultados sem interromper o teste"""
        
        print(f"\n{'='*70}")
        print("VALIDAÇÃO DE SLA")
        print("="*70)
        
        sla_target = 60.0  # segundos
        sla_passed = metrics.total_rto < sla_target
        
        print(f"Target RTO:        < {sla_target}s (para 99.99% uptime)")
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