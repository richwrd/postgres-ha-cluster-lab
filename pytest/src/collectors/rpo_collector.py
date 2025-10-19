"""
Coletor de métricas RPO

Versão assíncrona usando ClusterObserver para detecção precisa de eventos.
Monitora replicação e detecta perda de dados em tempo real.
"""
import asyncio
import time
from datetime import datetime
from typing import Optional
from src.models.rpo_metrics import RPOMetrics
from src.core.cluster_observer import ClusterObserver
from src.core.patroni_manager import PatroniManager
from src.core.postgres_manager import PostgresManager


class RPOCollector:
    """
    Coletor de métricas RPO com observação assíncrona
    
    Monitora transações e replicação para detectar perda de dados
    após failover com precisão.
    """
    
    def __init__(self, run_id: str):
        self.run_id = run_id
        self.metrics = None
        self.observer = ClusterObserver(poll_interval=0.1)  # 100ms
        self.patroni = PatroniManager()
        self.postgres = PostgresManager()
        self.test_table = "rpo_test"
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
    
    def start_measurement(self, test_case: str, failed_node: str) -> RPOMetrics:
        """
        Inicia medição de RPO
        
        IMPORTANTE: Chame start_observation() ANTES de chamar este método
        """
        timestamp = datetime.utcnow().isoformat()
        self._failure_injection_time = time.time()
        
        self.metrics = RPOMetrics(
            run_id=self.run_id,
            test_case=test_case,
            failed_node=failed_node
        )
        return self.metrics
    
    def setup_test_table(self) -> bool:
        """Cria tabela de teste para verificar RPO"""
        return self.postgres.create_test_table(self.test_table)

    def drop_test_table(self) -> bool:
        """Remove tabela de teste"""
        return self.postgres.drop_test_table(self.test_table)

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
                self.metrics.new_primary_node = new_primary
            
            elapsed = event.timestamp - self._failure_injection_time if self._failure_injection_time else 0
            print(f"  ✓ Novo primário eleito: {new_primary} ({elapsed:.3f}s)")
            return new_primary
        
        print(f"  ⚠️  Timeout aguardando novo primário")
        return None
    
    async def verify_data_after_recovery(self) -> int:
        """
        Verifica quantos dados foram recuperados após failover
        
        Returns:
            Número total de registros recuperados
        """
        if self.metrics:
            self.metrics.first_read_after_recovery = datetime.utcnow().isoformat()
        
        # Executa consulta em thread para não bloquear async
        loop = asyncio.get_event_loop()
        count = await loop.run_in_executor(
            None,
            self.postgres.count_records,
            self.test_table
        )
        
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
    
    def finalize_metrics(self):
        """Calcula métricas finais"""
        if self.metrics:
            self.metrics.calculate_metrics()
    
    def get_metrics(self) -> Optional[RPOMetrics]:
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
