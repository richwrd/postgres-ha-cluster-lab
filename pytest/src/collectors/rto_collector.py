"""
Coletor de métricas RTO
"""
import time
from datetime import datetime
from typing import Optional
from src.models.rto_metrics import RTOMetrics
from src.core.patroni_manager import PatroniManager
from src.core.postgres_manager import PostgresManager


class RTOCollector:
    """Coletor de métricas RTO"""
    
    def __init__(self, run_id: str):
        self.run_id = run_id
        self.metrics = None
        self.patroni = PatroniManager()
        self.postgres = PostgresManager()
    
    def start_measurement(self, test_case: str, failed_node: str, 
                         failure_type: str = "stop") -> RTOMetrics:
        """Inicia medição de RTO"""
        self.metrics = RTOMetrics(
            run_id=self.run_id,
            test_case=test_case,
            failed_node=failed_node,
            failure_type=failure_type,
            failure_injected_at=datetime.utcnow().isoformat()
        )
        return self.metrics
    
    def mark_failure_detected(self):
        """Marca quando a falha foi detectada"""
        if self.metrics:
            self.metrics.failure_detected_at = datetime.utcnow().isoformat()
    
    def mark_new_primary_elected(self, new_primary: str):
        """Marca quando novo primário foi eleito"""
        if self.metrics:
            self.metrics.new_primary_elected_at = datetime.utcnow().isoformat()
            self.metrics.new_primary_node = new_primary
    
    def mark_service_restored(self):
        """Marca quando serviço foi restaurado"""
        if self.metrics:
            self.metrics.service_restored_at = datetime.utcnow().isoformat()
            self.metrics.calculate_metrics()
    
    def get_current_primary(self) -> Optional[str]:
        """Identifica o nó primário atual"""
        return self.patroni.get_primary_node()
    
    def wait_for_new_primary(self, timeout: int = 60, old_primary: Optional[str] = None) -> Optional[str]:
        """Aguarda eleição de novo primário"""
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            primary = self.get_current_primary()
            if primary and (old_primary is None or primary != old_primary):
                return primary
            time.sleep(1)
        
        return None
    
    def wait_for_service_available(self, timeout: int = 60) -> bool:
        """Aguarda serviço PostgreSQL estar disponível"""
        return self.postgres.wait_until_available(max_wait=timeout)
    
    def get_metrics(self) -> Optional[RTOMetrics]:
        """Retorna as métricas coletadas"""
        return self.metrics
