"""
Coletor de métricas RTO

Versão assíncrona usando ClusterObserver para detecção precisa de eventos.
Elimina sleeps e polling manual para medições de RTO mais precisas.
"""
import asyncio
import time
from datetime import datetime
from typing import Optional
from src.models.rto_metrics import RTOMetrics
from src.core.cluster_observer import ClusterObserver
from src.core.postgres_manager import PostgresManager


class RTOCollector:
    """
    Coletor de métricas RTO com observação assíncrona
    
    Monitora todos os nós do cluster simultaneamente para capturar
    eventos de falha e recuperação com precisão de milissegundos.
    """
    
    def __init__(self, run_id: str):
        self.run_id = run_id
        self.metrics = None
        self.observer = ClusterObserver(poll_interval=0.1)  # 100ms
        self.postgres = PostgresManager()
        self._observation_started = False
        self._failure_injection_time = None
    
    async def start_observation(self):
        """Inicia observação assíncrona do cluster"""
        if not self._observation_started:
            await self.observer.start_observing()
            self._observation_started = True
            # Aguarda estabilização inicial
            await asyncio.sleep(0.2)
    
    async def stop_observation(self):
        """Para observação do cluster"""
        if self._observation_started:
            await self.observer.stop_observing()
            self._observation_started = False
    
    def start_measurement(self, test_case: str, failed_node: str, 
                         failure_type: str = "stop") -> RTOMetrics:
        """
        Inicia medição de RTO
        
        IMPORTANTE: Chame start_observation() ANTES de chamar este método
        """
        timestamp = datetime.utcnow().isoformat()
        self._failure_injection_time = time.time()
        
        self.metrics = RTOMetrics(
            run_id=self.run_id,
            test_case=test_case,
            failed_node=failed_node,
            failure_type=failure_type,
            failure_injected_at=timestamp
        )
        return self.metrics
    
    async def wait_for_failure_detection(self, timeout: float = 30) -> bool:
        """
        Aguarda detecção da falha pelo cluster
        
        Observa quando os nós restantes percebem a falha (loss of quorum)
        
        Returns:
            True se falha foi detectada
        """
        print(f"  ⏱️  Aguardando detecção (timeout: {timeout}s)...")
        
        event = await self.observer.wait_for_event("failure_detected", timeout=timeout)
        
        if event:
            if self.metrics:
                self.metrics.failure_detected_at = datetime.fromtimestamp(event.timestamp).isoformat()
            
            detection_time = event.timestamp - self._failure_injection_time
            print(f"  ✓ Falha detectada em {detection_time:.3f}s")
            return True
        
        print(f"  ⚠️  Timeout aguardando detecção")
        return False
    
    async def wait_for_new_primary(self, timeout: float = 60, old_primary: Optional[str] = None) -> Optional[str]:
        """
        Aguarda eleição de novo primário
        
        Observa eventos de mudança de role para Leader
        
        Returns:
            Nome do novo primário ou None se timeout
        """
        print(f"  ⏱️  Aguardando novo primário (timeout: {timeout}s)...")
        
        start = time.time()
        event = await self.observer.wait_for_event("new_primary", timeout=timeout)
        
        if event:
            new_primary = event.node
            
            # Valida que é diferente do antigo
            if old_primary and new_primary == old_primary:
                print(f"  ⚠️  Mesmo primário detectado, aguardando mudança...")
                # Continua aguardando
                remaining = timeout - (time.time() - start)
                if remaining > 0:
                    event = await self.observer.wait_for_event("new_primary", timeout=remaining)
                    if event:
                        new_primary = event.node
            
            if self.metrics:
                self.metrics.new_primary_elected_at = datetime.fromtimestamp(event.timestamp).isoformat()
                self.metrics.new_primary_node = new_primary
            
            election_time = event.timestamp - self._failure_injection_time
            print(f"  ✓ Novo primário eleito: {new_primary} ({election_time:.3f}s)")
            return new_primary
        
        print(f"  ⚠️  Timeout aguardando novo primário")
        return None
    
    async def wait_for_service_available(self, timeout: float = 60) -> bool:
        """
        Aguarda serviço PostgreSQL estar disponível
        
        Tenta conexões ao cluster via pgpool/novo primário
        
        Returns:
            True se serviço disponível
        """
        print(f"  ⏱️  Aguardando serviço disponível (timeout: {timeout}s)...")
        
        event = await self.observer.wait_for_event("service_restored", timeout=timeout)
        if event:
            if self.metrics:
                self.metrics.service_restored_at = datetime.utcnow().isoformat()
            print(f"  ✓ Serviço disponível")
            return True
        
        print(f"  ⚠️  Timeout aguardando serviço")
        return False
    
    def finalize_metrics(self):
        """Calcula métricas finais"""
        if self.metrics:
            self.metrics.calculate_metrics()
    
    def get_metrics(self) -> Optional[RTOMetrics]:
        """Retorna as métricas coletadas"""
        return self.metrics
    
    def get_cluster_state(self):
        """Retorna estado atual do cluster observado"""
        return self.observer.get_cluster_state()
    
    def get_events_summary(self) -> str:
        """Retorna resumo dos eventos detectados"""
        events = self.observer.events
        if not events:
            return "Nenhum evento detectado"
        
        summary = [f"\n{'='*60}", "EVENTOS DETECTADOS", "="*60]
        
        for i, event in enumerate(events, 1):
            elapsed = event.timestamp - self._failure_injection_time if self._failure_injection_time else 0
            summary.append(f"{i}. [{elapsed:6.3f}s] {event.event_type:20s} | {event.node}")
        
        summary.append("="*60)
        return "\n".join(summary)
