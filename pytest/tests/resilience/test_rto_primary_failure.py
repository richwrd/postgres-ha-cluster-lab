"""
Teste de RTO - Falha do Nó Primário

Simula falha completa do nó primário e mede tempo de recuperação
"""
import pytest
import time
from src.core.docker_manager import DockerManager


@pytest.mark.rto
@pytest.mark.resilience
class TestRTOPrimaryFailure:
    
    def test_primary_node_complete_failure(
        self,
        rto_collector,
        rto_writer,
        cluster_healthy,
        get_primary_node
    ):
        """
        3.4.1 - Teste de Resiliência (RTO)
        
        Procedimento:
        1. Identifica nó primário
        2. Para o container (docker stop)
        3. Mede tempo até novo primário ser eleito
        4. Mede tempo até API responder 200 OK
        
        SLA: RTO < 60 segundos
        """
        docker = DockerManager()
        
        # 1. Identifica primário
        print("\n[1/5] Identificando nó primário...")
        initial_primary = get_primary_node()
        assert initial_primary, "Primário não identificado"
        print(f"✓ Primário: {initial_primary}")
        
        # 2. Injeta falha
        print(f"\n[2/5] Parando {initial_primary}...")
        metrics = rto_collector.start_measurement(
            "primary_complete_failure",
            initial_primary,
            "stop"
        )
        
        success = docker.stop_container(initial_primary)
        assert success, "Falha ao parar container"
        print("✓ Container parado")
        
        # 3. Aguarda detecção
        print("\n[3/5] Aguardando detecção...")
        time.sleep(3)
        rto_collector.mark_failure_detected()
        print("✓ Falha detectada")
        
        # 4. Aguarda novo primário
        print("\n[4/5] Aguardando novo primário...")
        new_primary = rto_collector.wait_for_new_primary(
            timeout=60,
            old_primary=initial_primary
        )
        assert new_primary, "Timeout aguardando novo primário"
        assert new_primary != initial_primary
        
        rto_collector.mark_new_primary_elected(new_primary)
        print(f"✓ Novo primário: {new_primary}")
        
        # 5. Aguarda serviço disponível
        print("\n[5/5] Aguardando serviço disponível...")
        service_ok = rto_collector.wait_for_service_available(timeout=30)
        assert service_ok, "Serviço não disponível"
        
        rto_collector.mark_service_restored()
        print("✓ Serviço disponível")
        
        # Salva métricas
        metrics = rto_collector.get_metrics()
        rto_writer.write(metrics)
        
        # Exibe resultados
        self._print_rto_metrics(metrics)
        
        # Valida SLA
        assert metrics.total_rto < 60, \
            f"RTO ({metrics.total_rto:.2f}s) excedeu 60s"
        
        print(f"\n✅ RTO: {metrics.total_rto:.2f}s (SLA: <60s)")
        
        # Cleanup
        print(f"\n[Cleanup] Reiniciando {initial_primary}...")
        docker.start_container(initial_primary)
        time.sleep(5)
        print("✓ Cleanup concluído")
    
    def _print_rto_metrics(self, metrics):
        """Exibe métricas formatadas"""
        print("\n" + "="*60)
        print("MÉTRICAS DE RTO")
        print("="*60)
        print(f"Tipo de falha:     {metrics.failure_type}")
        print(f"Nó que falhou:     {metrics.failed_node}")
        print(f"Novo primário:     {metrics.new_primary_node}")
        print("-"*60)
        print(f"Tempo detecção:    {metrics.detection_time:.2f}s")
        print(f"Tempo eleição:     {metrics.election_time:.2f}s")
        print(f"Tempo restauração: {metrics.restoration_time:.2f}s")
        print(f"RTO TOTAL:         {metrics.total_rto:.2f}s")
        print("="*60)
