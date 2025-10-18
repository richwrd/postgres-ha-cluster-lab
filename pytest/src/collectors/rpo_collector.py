"""
Coletor de métricas RPO
"""
from datetime import datetime
from typing import Optional
from src.models.rpo_metrics import RPOMetrics
from src.core.patroni_manager import PatroniManager
from src.core.postgres_manager import PostgresManager


class RPOCollector:
    """Coletor de métricas RPO"""
    
    def __init__(self, run_id: str):
        self.run_id = run_id
        self.metrics = None
        self.patroni = PatroniManager()
        self.postgres = PostgresManager()
        self.test_table = "rpo_test"
    
    def start_measurement(self, test_case: str, failed_node: str) -> RPOMetrics:
        """Inicia medição de RPO"""
        self.metrics = RPOMetrics(
            run_id=self.run_id,
            test_case=test_case,
            failed_node=failed_node
        )
        return self.metrics
    
    def setup_test_table(self) -> bool:
        """Cria tabela de teste para verificar RPO"""
        return self.postgres.create_test_table(self.test_table)
    
    def write_transaction(self, data: str = "test_data") -> Optional[int]:
        """
        Escreve uma transação e retorna o ID
        
        Returns:
            ID da transação ou None se falhar
        """
        transaction_id = self.postgres.insert_test_data(self.test_table, data)
        
        if transaction_id and self.metrics:
            self.metrics.last_transaction_id_written = transaction_id
            self.metrics.last_write_before_failure = datetime.utcnow().isoformat()
        
        return transaction_id
    
    def mark_failure_occurred(self):
        """Marca o momento da falha"""
        if self.metrics:
            self.metrics.failure_occurred_at = datetime.utcnow().isoformat()
    
    def mark_new_primary_elected(self, new_primary: str):
        """Marca quando novo primário foi eleito"""
        if self.metrics:
            self.metrics.new_primary_node = new_primary
    
    def verify_data_after_recovery(self) -> int:
        """
        Verifica quantos dados foram recuperados após failover
        
        Returns:
            Número total de registros recuperados
        """
        if self.metrics:
            self.metrics.first_read_after_recovery = datetime.utcnow().isoformat()
        
        count = self.postgres.count_records(self.test_table)
        
        if count and self.metrics:
            # O último ID recuperado é igual ao count (assumindo SERIAL)
            self.metrics.last_transaction_id_recovered = count
            self.metrics.calculate_metrics()
        
        return count or 0
    
    def measure_replication_lag(self) -> Optional[int]:
        """
        Mede o lag de replicação (em bytes) antes da falha
        
        Returns:
            Lag em bytes ou None
        """
        lag = self.postgres.get_replication_lag()
        if lag and self.metrics:
            self.metrics.replication_lag_bytes = lag
        return lag
    
    def get_metrics(self) -> Optional[RPOMetrics]:
        """Retorna as métricas coletadas"""
        return self.metrics
