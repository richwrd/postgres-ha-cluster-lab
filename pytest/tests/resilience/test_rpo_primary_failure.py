"""
Teste de RPO - Falha do Nó Primário

Verifica se há perda de dados após failover
"""
import pytest
import time
from src.core.docker_manager import DockerManager


@pytest.mark.rpo
@pytest.mark.resilience
class TestRPOPrimaryFailure:
    
    def test_primary_failure_data_loss(
        self,
        rpo_collector,
        rpo_writer,
        cluster_healthy,
        get_primary_node
    ):
        """
        3.4.1 - Teste de Resiliência (RPO)
        
        Procedimento:
        1. Cria tabela de teste
        2. Escreve transações no primário
        3. Simula falha do primário
        4. Verifica se todas as transações foram recuperadas
        
        SLA: RPO = 0 (sem perda de dados)
        """
        docker = DockerManager()
        
        # 1. Setup - Cria tabela de teste
        print("\n[1/6] Criando tabela de teste...")
        success = rpo_collector.setup_test_table()
        assert success, "Falha ao criar tabela de teste"
        print("✓ Tabela criada")
        
        # 2. Identifica primário
        print("\n[2/6] Identificando primário...")
        initial_primary = get_primary_node()
        assert initial_primary, "Primário não identificado"
        print(f"✓ Primário: {initial_primary}")
        
        metrics = rpo_collector.start_measurement(
            "primary_failure_rpo",
            initial_primary
        )
        
        # 3. Escreve transações de teste
        print("\n[3/6] Escrevendo transações...")
        num_transactions = 10
        for i in range(num_transactions):
            tx_id = rpo_collector.write_transaction(f"test_data_{i}")
            assert tx_id, f"Falha ao escrever transação {i}"
        
        last_tx_id = rpo_collector.metrics.last_transaction_id_written
        print(f"✓ {num_transactions} transações escritas")
        print(f"  Última TX ID: {last_tx_id}")
        
        # Aguarda replicação
        time.sleep(2)
        
        # 4. Injeta falha
        print(f"\n[4/6] Parando {initial_primary}...")
        rpo_collector.mark_failure_occurred()
        
        success = docker.stop_container(initial_primary)
        assert success, "Falha ao parar container"
        print("✓ Container parado")
        
        # 5. Aguarda novo primário
        print("\n[5/6] Aguardando novo primário...")
        time.sleep(10)  # Aguarda failover
        
        # 6. Verifica dados recuperados
        print("\n[6/6] Verificando dados recuperados...")
        recovered_count = rpo_collector.verify_data_after_recovery()
        
        metrics = rpo_collector.get_metrics()
        rpo_writer.write(metrics)
        
        # Exibe resultados
        self._print_rpo_metrics(metrics, num_transactions)
        
        # Valida RPO = 0
        assert metrics.transactions_lost == 0, \
            f"Perda de dados detectada: {metrics.transactions_lost} transações"
        
        print(f"\n✅ RPO = 0 (sem perda de dados)")
        
        # Cleanup
        print(f"\n[Cleanup] Reiniciando {initial_primary}...")
        docker.start_container(initial_primary)
        time.sleep(5)
        print("✓ Cleanup concluído")
    
    def _print_rpo_metrics(self, metrics, expected_count):
        """Exibe métricas formatadas"""
        print("\n" + "="*60)
        print("MÉTRICAS DE RPO")
        print("="*60)
        print(f"Nó que falhou:         {metrics.failed_node}")
        print(f"Novo primário:         {metrics.new_primary_node}")
        print("-"*60)
        print(f"TXs escritas:          {metrics.last_transaction_id_written}")
        print(f"TXs recuperadas:       {metrics.last_transaction_id_recovered}")
        print(f"TXs perdidas:          {metrics.transactions_lost}")
        print(f"Houve perda de dados:  {'SIM' if metrics.data_loss_occurred else 'NÃO'}")
        print("="*60)
