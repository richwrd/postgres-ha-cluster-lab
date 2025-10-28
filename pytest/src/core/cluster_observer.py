"""
Observador assíncrono de eventos do cluster Patroni

Monitora todos os nós simultaneamente para detectar mudanças de estado em tempo real.
Elimina a necessidade de sleeps e polling manual.
"""
import asyncio
import json
import time
from typing import Optional, List, Dict, Any, Callable
from datetime import datetime
from .docker_manager import DockerManager
from .patroni_manager import PatroniManager
from .postgres_manager import PostgresManager
from .config import config


class ClusterEvent:
    """Representa um evento detectado no cluster"""
    
    def __init__(self, event_type: str, node: str, timestamp: float, data: Any = None):
        self.event_type = event_type
        self.node = node
        self.timestamp = timestamp
        self.data = data
    
    def __repr__(self):
        return f"ClusterEvent({self.event_type}, {self.node}, {self.timestamp:.3f}s)"


class ClusterObserver:
    """
    Observa o cluster Patroni de forma assíncrona
    
    Monitora todos os nós simultaneamente e detecta:
    - Falhas de nó (container down, healthcheck fail)
    - Mudanças de role (replica -> leader)
    - Eleições de novo primário
    - Restauração de serviço
    """
    
    def __init__(self, nodes: Optional[List[str]] = None, poll_interval: float = 0.5):
        """
        Args:
            nodes: Lista de nós Patroni para monitorar (None = todos do config)
            poll_interval: Intervalo de polling em segundos (padrão: 100ms)
        """
        self.nodes = nodes or config.patroni_nodes
        self.poll_interval = poll_interval
        self.docker = DockerManager()
        self.patroni = PatroniManager()
        self.postgres = PostgresManager()
        
        # Eventos detectados
        self.events: List[ClusterEvent] = []
        
        # Controle de observação
        self._observing = False
        self._tasks: List[asyncio.Task] = []
        
        # Callbacks para eventos específicos
        self._event_callbacks: Dict[str, List[Callable]] = {}
        
        self.old_primary: Optional[str] = None
        self.new_primary: Optional[str] = None
        
        self.cluster_failed: bool = False
        self.cluster_restored: bool = False
        self.cluster_switchover: bool = False
    
    def on_event(self, event_type: str, callback: Callable):
        """
        Registra callback para tipo de evento
        
        Args:
            event_type: Tipo de evento ('failure_detected', 'new_primary', 'service_restored')
            callback: Função a chamar quando evento ocorrer
        """
        if event_type not in self._event_callbacks:
            self._event_callbacks[event_type] = []
        self._event_callbacks[event_type].append(callback)
    
    def _emit_event(self, event: ClusterEvent):
        """Emite evento e chama callbacks registrados"""
        self.events.append(event)
        
        if event.event_type in self._event_callbacks:
            for callback in self._event_callbacks[event.event_type]:
                try:
                    callback(event)
                except Exception as e:
                    print(f"⚠️  Erro em callback: {e}")
      
    async def start_observing(self):
        """Inicia observação assíncrona rotacionando entre os nós"""
        if self._observing:
            return
        
        print(f"🔍 Iniciando observação de {len(self.nodes)} nós (poll: {self.poll_interval*1000:.0f}ms)")
        
        self._observing = True
        self.events.clear()
        
        self.old_primary = self.patroni.get_primary_node()
        
        task_1 = asyncio.create_task(self._detect_cluster_failure())
        self._tasks.append(task_1)
        
        task_2 = asyncio.create_task(self._detect_new_primary())
        self._tasks.append(task_2)
        
        task_3 = asyncio.create_task(self._detect_service_restoration())
        self._tasks.append(task_3)
        
        await asyncio.sleep(0.5)  # Pequeno delay para estabilizar

    async def start_observing_switchover(self):
        """Inicia observação assíncrona rotacionando entre os nós"""
        if self._observing:
            return
        
        print(f"🔍 Iniciando observação de {len(self.nodes)} nós (poll: {self.poll_interval*1000:.0f}ms)")
        
        self._observing = True
        self.events.clear()
        
        self.old_primary = self.patroni.get_primary_node()
        
        task_1 = asyncio.create_task(self._detect_cluster_new_primary())
        self._tasks.append(task_1)
        
        task_3 = asyncio.create_task(self._detect_service_restoration_switchover())
        self._tasks.append(task_3)
        
        await asyncio.sleep(0.5)  # Pequeno delay para estabilizar

        
    async def stop_observing(self):
        """Para observação"""
        if not self._observing:
            return
        
        print(f"🛑 Parando observação ({len(self.events)} eventos detectados)")
        
        self._observing = False
        
        # Cancela todas as tasks
        for task in self._tasks:
            task.cancel()
        
        # Aguarda cancelamento
        await asyncio.gather(*self._tasks, return_exceptions=True)
        self._tasks.clear()
    
    def get_event(self, event_type: str, since: Optional[float] = None) -> Optional[ClusterEvent]:
        """
        Busca primeiro evento de um tipo
        
        Args:
            event_type: Tipo do evento
            since: Timestamp mínimo (None = qualquer)
        
        Returns:
            Evento encontrado ou None
        """
        for event in self.events:
            if event.event_type == event_type:
                if since is None or event.timestamp >= since:
                    return event
        return None
    
    async def wait_for_event(self, event_type: str, timeout: float = 60) -> Optional[ClusterEvent]:
        """
        Aguarda um evento específico
        
        Args:
            event_type: Tipo do evento
            timeout: Timeout em segundos
        
        Returns:
            Evento quando ocorrer ou None se timeout
        """
        start = time.time()
        
        while time.time() - start < timeout:
            event = self.get_event(event_type, since=start)
            if event:
                return event
            await asyncio.sleep(0.05)  # 50ms
        
        return None
    
    async def _detect_cluster_failure(self):
        """
        Detecta falhas no cluster através do Patroni API
        Identifica quando todos os nós estão com State=running (ausência de líder por muito tempo (loop_wait exceeded))
        """
        print(f"🔍 Detectando falhas no cluster...")
        
        while self._observing and not self.cluster_failed:
            try:
                members = self.patroni.get_cluster_members()
                
                if members:
                    # Verifica se TODOS os membros estão com State=running
                    all_running = all(
                        member.get('State') == 'running' 
                        for member in members
                    )
                    
                    if all_running and len(members) > 1:
                        event = ClusterEvent(
                            event_type='failure_detected',
                            node='cluster',
                            timestamp=time.time(),
                            data={
                                'reason': 'all_nodes_running, loop_wait exceeded',
                                'members': members
                            }
                        )
                        self._emit_event(event)
                        print(f"⚠️  ALERTA: Todos os nós com State=running (loop_wait exceeded)")
                        
                        self.cluster_failed = True
                        
            except Exception as e:
                print(f"⚠️  Erro ao detectar falha no cluster: {e}")
            
            await asyncio.sleep(self.poll_interval)


    async def _detect_new_primary(self):
        """
        Detecta eleição de novo primário no cluster
        """
        print(f"🔍 Detectando eleição de novo primário...")
    
        
        while self._observing:
            try:
                if self.cluster_failed and not self.cluster_restored:
                    self.new_primary = self.patroni.get_primary_node()
                    last_primary = self.old_primary
                    
                    if self.new_primary and self.new_primary != last_primary:
                        event = ClusterEvent(
                            event_type='new_primary',
                            node=self.new_primary,
                            timestamp=time.time(),
                            data=None
                        )
                        self._emit_event(event)
                        print(f"✅ Novo primário detectado: {self.new_primary}")
                        last_primary = self.new_primary
                        
                        self.cluster_restored = True
                        
            except Exception as e:
                print(f"⚠️  Erro ao detectar novo primário: {e}")
            
            await asyncio.sleep(self.poll_interval)
        
    async def _detect_service_restoration(self):
        """
        Detecta restauração do serviço PostgreSQL via pgpool
        """
        print(f"🔍 Detectando restauração do serviço PostgreSQL...")
        
        while self._observing:
            try:
                if self.cluster_restored:
                    
                    if not self.cluster_switchover:
                    
                        if self.postgres.is_available():
                            event = ClusterEvent(
                                event_type='service_restored',
                                node='pgpool',
                                timestamp=time.time(),
                                data=None
                            )
                            self._emit_event(event)
                            print(f"✅ Serviço PostgreSQL restaurado e disponível via pgpool")
                            
                            self.cluster_switchover = True
                            
            except Exception as e:
                print(f"⚠️  Erro ao detectar restauração do serviço: {e}")
            
            await asyncio.sleep(self.poll_interval)


    async def _detect_service_restoration_switchover(self):
        """
        Detecta restauração do serviço PostgreSQL via pgpool
        """
        print(f"🔍 Detectando restauração do serviço PostgreSQL...")
        
        while self._observing:
            try:
                if self.cluster_restored:
                
                    if self.postgres.is_available():
                        event = ClusterEvent(
                            event_type='service_restored',
                            node='pgpool',
                            timestamp=time.time(),
                            data=None
                        )
                        self._emit_event(event)
                        print(f"✅ Serviço PostgreSQL restaurado e disponível via pgpool")
                        
            except Exception as e:
                print(f"⚠️  Erro ao detectar restauração do serviço: {e}")
            
            await asyncio.sleep(self.poll_interval)
    
    async def _detect_cluster_new_primary(self):
        """
        Detecta mudança de primário no cluster
        Identifica quando o primário atual é diferente do primário anterior
        """
        print(f"🔍 Detectando mudança de primário no cluster...")
        
        while self._observing:
            try:
                current_primary = self.patroni.get_primary_node()
                
                if not self.cluster_switchover:
                
                    if current_primary and current_primary != self.old_primary:
                        event = ClusterEvent(
                            event_type='new_primary',
                            node=current_primary,
                            timestamp=time.time(),
                            data={
                                'old_primary': self.old_primary,
                                'new_primary': current_primary
                            }
                        )
                        self.cluster_switchover = True
                        self._emit_event(event)
                        print(f"✅ Novo primário detectado: {current_primary} (anterior: {self.old_primary})")
                        
                        self.new_primary = current_primary
                        self.cluster_restored = True
                            
            except Exception as e:
                print(f"⚠️  Erro ao detectar mudança de primário: {e}")
            
            await asyncio.sleep(self.poll_interval)

