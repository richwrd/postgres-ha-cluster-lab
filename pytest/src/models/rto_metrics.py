"""
Métricas de RTO (Recovery Time Objective)
"""
from dataclasses import dataclass, asdict
from datetime import datetime
from typing import Optional, Dict, Any


@dataclass
class RTOMetrics:
    """Métricas de RTO para testes de resiliência"""
    run_id: str
    test_case: str
    
    # Timestamps críticos
    failure_injected_at: Optional[str] = None
    failure_detected_at: Optional[str] = None
    new_primary_elected_at: Optional[str] = None
    service_restored_at: Optional[str] = None
    
    # Métricas calculadas (em segundos)
    detection_time: Optional[float] = None
    election_time: Optional[float] = None
    restoration_time: Optional[float] = None
    total_rto: Optional[float] = None
    
    # Dados do cluster
    failed_node: Optional[str] = None
    new_primary_node: Optional[str] = None
    failure_type: Optional[str] = None  # 'stop', 'kill', 'pause', 'network'
    
    def calculate_metrics(self):
        """Calcula as métricas de tempo baseado nos timestamps"""
        if self.failure_injected_at and self.failure_detected_at:
            t1 = datetime.fromisoformat(self.failure_injected_at)
            t2 = datetime.fromisoformat(self.failure_detected_at)
            self.detection_time = (t2 - t1).total_seconds()
        
        if self.failure_detected_at and self.new_primary_elected_at:
            t1 = datetime.fromisoformat(self.failure_detected_at)
            t2 = datetime.fromisoformat(self.new_primary_elected_at)
            self.election_time = (t2 - t1).total_seconds()
        
        if self.new_primary_elected_at and self.service_restored_at:
            t1 = datetime.fromisoformat(self.new_primary_elected_at)
            t2 = datetime.fromisoformat(self.service_restored_at)
            self.restoration_time = (t2 - t1).total_seconds()
        
        if self.failure_injected_at and self.service_restored_at:
            t1 = datetime.fromisoformat(self.failure_injected_at)
            t2 = datetime.fromisoformat(self.service_restored_at)
            self.total_rto = (t2 - t1).total_seconds()
    
    def to_json(self) -> Dict[str, Any]:
        """Converte para dicionário JSON"""
        return asdict(self)
