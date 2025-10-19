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
    
    def __init__(self, nodes: Optional[List[str]] = None, poll_interval: float = 0.1):
        """
        Args:
            nodes: Lista de nós Patroni para monitorar (None = todos do config)
            poll_interval: Intervalo de polling em segundos (padrão: 100ms)
        """
        self.nodes = nodes or config.patroni_nodes
        self.poll_interval = poll_interval
        self.docker = DockerManager()
        
        # Estado do cluster
        self._cluster_state: Dict[str, Dict[str, Any]] = {}
        self._previous_state: Dict[str, Dict[str, Any]] = {}
        
        # Eventos detectados
        self.events: List[ClusterEvent] = []
        
        # Controle de observação
        self._observing = False
        self._tasks: List[asyncio.Task] = []
        
        # Callbacks para eventos específicos
        self._event_callbacks: Dict[str, List[Callable]] = {}
    
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
    
    async def _get_node_status(self, node: str) -> Optional[Dict[str, Any]]:
        """
        Obtém status de um nó via API do Patroni
        
        Returns:
            Dict com: role, state, timeline, lag, etc.
        """
        try:
            # Executa patronictl list para este nó específico
            cmd = ["patronictl", "list", "-f", "json"]
            
            # Executa de forma assíncrona
            loop = asyncio.get_event_loop()
            output = await loop.run_in_executor(
                None,
                self.docker.exec_command,
                node,
                cmd,
                5  # timeout
            )
            
            if not output:
                return None
            
            # Parse JSON
            members = json.loads(output)
            
            # Encontra este nó na lista
            for member in members:
                if member.get("Member") == node:
                    return {
                        "role": member.get("Role"),
                        "state": member.get("State"),
                        "timeline": member.get("TL"),
                        "lag": member.get("Lag in MB"),
                        "pending_restart": member.get("Pending restart"),
                    }
            
            return None
            
        except Exception as e:
            # Nó inacessível
            return {"error": str(e), "accessible": False}
    
    async def _monitor_node(self, node: str):
        """
        Monitora um nó específico continuamente
        
        Detecta mudanças de estado e emite eventos
        """
        while self._observing:
            try:
                status = await self._get_node_status(node)
                current_time = time.time()
                
                # Atualiza estado
                previous = self._cluster_state.get(node, {})
                self._cluster_state[node] = status or {"accessible": False}
                
                # Detecta mudanças
                if previous and status:
                    # Detecta mudança de role
                    if previous.get("role") != status.get("role"):
                        if status.get("role") == "Leader":
                            event = ClusterEvent(
                                "new_primary",
                                node,
                                current_time,
                                {"old_role": previous.get("role"), "new_role": "Leader"}
                            )
                            self._emit_event(event)
                    
                    # Detecta mudança de state
                    if previous.get("state") != status.get("state"):
                        if status.get("state") == "running":
                            event = ClusterEvent(
                                "node_recovered",
                                node,
                                current_time,
                                {"old_state": previous.get("state"), "new_state": "running"}
                            )
                            self._emit_event(event)
                
                # Detecta nó inacessível
                if previous.get("accessible") != False and status.get("accessible") == False:
                    event = ClusterEvent(
                        "node_unreachable",
                        node,
                        current_time,
                        {"reason": status.get("error")}
                    )
                    self._emit_event(event)
                
                await asyncio.sleep(self.poll_interval)
                
            except Exception as e:
                print(f"⚠️  Erro monitorando {node}: {e}")
                await asyncio.sleep(self.poll_interval)
    
    async def _monitor_cluster_consensus(self):
        """
        Monitora consenso do cluster (visão global)
        
        Detecta quando réplicas percebem falha do primário
        """
        while self._observing:
            try:
                # Conta quantos nós veem um primário
                primaries_seen = {}
                
                for node, status in self._cluster_state.items():
                    if status and status.get("role") == "Leader":
                        primaries_seen[node] = primaries_seen.get(node, 0) + 1
                
                # Se nenhum nó se vê como Leader, houve perda de consenso
                if not primaries_seen and self._cluster_state:
                    # Verifica se já emitiu evento de "failure_detected"
                    if not any(e.event_type == "failure_detected" for e in self.events):
                        event = ClusterEvent(
                            "failure_detected",
                            "cluster",
                            time.time(),
                            {"reason": "no_leader_consensus"}
                        )
                        self._emit_event(event)
                
                await asyncio.sleep(self.poll_interval)
                
            except Exception as e:
                print(f"⚠️  Erro monitorando consenso: {e}")
                await asyncio.sleep(self.poll_interval)
    
    async def start_observing(self):
        """Inicia observação assíncrona de todos os nós"""
        if self._observing:
            return
        
        print(f"🔍 Iniciando observação de {len(self.nodes)} nós (poll: {self.poll_interval*1000:.0f}ms)")
        
        self._observing = True
        self.events.clear()
        
        # Cria tasks para cada nó
        for node in self.nodes:
            task = asyncio.create_task(self._monitor_node(node))
            self._tasks.append(task)
        
        # Task para monitorar consenso
        consensus_task = asyncio.create_task(self._monitor_cluster_consensus())
        self._tasks.append(consensus_task)
    
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
    
    def get_current_primary(self) -> Optional[str]:
        """Retorna nó primário atual baseado no estado observado"""
        for node, status in self._cluster_state.items():
            if status and status.get("role") == "Leader":
                return node
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
    
    def get_cluster_state(self) -> Dict[str, Any]:
        """Retorna snapshot do estado atual do cluster"""
        primary = None
        replicas = []
        unreachable = []
        
        for node, status in self._cluster_state.items():
            if status.get("accessible") == False:
                unreachable.append(node)
            elif status.get("role") == "Leader":
                primary = node
            elif status.get("role") == "Replica":
                replicas.append(node)
        
        return {
            "timestamp": datetime.utcnow().isoformat(),
            "primary": primary,
            "replicas": replicas,
            "unreachable": unreachable,
            "total_nodes": len(self.nodes)
        }
