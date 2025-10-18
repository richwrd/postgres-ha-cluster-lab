"""
Métricas de RPO (Recovery Point Objective)
"""
from dataclasses import dataclass, asdict
from datetime import datetime
from typing import Optional, Dict, Any


@dataclass
class RPOMetrics:
    """Métricas de RPO para testes de resiliência"""
    run_id: str
    test_case: str
    
    # Timestamps
    last_write_before_failure: Optional[str] = None
    failure_occurred_at: Optional[str] = None
    first_read_after_recovery: Optional[str] = None
    
    # Dados de transações
    last_transaction_id_written: Optional[int] = None
    last_transaction_id_recovered: Optional[int] = None
    transactions_lost: Optional[int] = None
    
    # Dados de replicação
    replication_lag_bytes: Optional[int] = None
    replication_lag_seconds: Optional[float] = None
    
    # Métricas calculadas
    data_loss_occurred: bool = False
    rpo_seconds: Optional[float] = None  # Tempo de perda de dados
    
    # Detalhes do teste
    failed_node: Optional[str] = None
    new_primary_node: Optional[str] = None
    
    def calculate_metrics(self):
        """Calcula as métricas de RPO"""
        # Calcula transações perdidas
        if self.last_transaction_id_written and self.last_transaction_id_recovered:
            self.transactions_lost = (
                self.last_transaction_id_written - self.last_transaction_id_recovered
            )
            self.data_loss_occurred = self.transactions_lost > 0
        
        # Calcula RPO em segundos
        if self.last_write_before_failure and self.failure_occurred_at:
            t1 = datetime.fromisoformat(self.last_write_before_failure)
            t2 = datetime.fromisoformat(self.failure_occurred_at)
            self.rpo_seconds = (t2 - t1).total_seconds()
    
    def to_json(self) -> Dict[str, Any]:
        """Converte para dicionário JSON"""
        return asdict(self)
