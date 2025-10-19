"""
Gerenciador de operações Patroni
"""
import json
import time
from typing import Optional, Dict, List, Any
from .docker_manager import DockerManager
from .config import config


class PatroniManager:
    """Gerencia operações com Patroni"""
    
    def __init__(self, patroni_container: Optional[str] = None):
        """
        Args:
            patroni_container: Nome de um container Patroni para executar comandos.
                              Se None, tenta todos os nós do .env em ordem
        """
        self.patroni_container = patroni_container
        self.docker = DockerManager()
    
    def _exec_on_available_node(self, command: List[str], timeout: int = 10) -> Optional[str]:
        """
        Executa comando em um nó Patroni disponível
        
        Tenta executar o comando em todos os nós Patroni em ordem até conseguir.
        Se patroni_container foi especificado, usa apenas ele.
        
        Args:
            command: Comando a executar
            timeout: Timeout em segundos
            
        Returns:
            Output do comando ou None se falhar em todos
        """
        if self.patroni_container:
            return self.docker.exec_command(
                self.patroni_container,
                command,
                timeout=timeout
            )
        
        for node in config.patroni_nodes:
            output = self.docker.exec_command(
                node,
                command,
                timeout=timeout
            )
            if output is not None:
                return output
        
        return None
    
    def get_cluster_members(self) -> Optional[List[Dict[str, Any]]]:
        """
        Obtém lista de membros do cluster
        
        Returns:
            Lista de dicionários com informações dos membros
        """
        output = self._exec_on_available_node(
            ["patronictl", "list", "-f", "json"],
            timeout=10
        )
        
        if output:
            try:
                return json.loads(output)
            except json.JSONDecodeError:
                return None
        return None
    
    def get_primary_node(self) -> Optional[str]:
        """
        Identifica o nó primário (Leader)
        
        Returns:
            Nome do nó primário ou None
        """
        members = self.get_cluster_members()
        if members:
            for member in members:
                if member.get("Role") == "Leader":
                    return member.get("Member")
        return None
    
    def get_replica_nodes(self) -> List[str]:
        """
        Identifica os nós réplica
        
        Returns:
            Lista de nomes dos nós réplica
        """
        replicas = []
        members = self.get_cluster_members()
        if members:
            for member in members:
                if member.get("Role") == "Replica":
                    replicas.append(member.get("Member"))
        return replicas
    
    def get_node_lag(self, node_name: str) -> Optional[int]:
        """
        Obtém o lag de replicação de um nó
        
        Args:
            node_name: Nome do nó
            
        Returns:
            Lag em bytes ou None
        """
        members = self.get_cluster_members()
        if members:
            for member in members:
                if member.get("Member") == node_name:
                    return member.get("Lag in MB")
        return None
    
    def failover(self, candidate: Optional[str] = None) -> bool:
        """
        Força um failover
        
        Args:
            candidate: Nome do candidato a primário (None = automático)
            
        Returns:
            True se sucesso
        """
        cmd = ["patronictl", "failover", "--force"]
        if candidate:
            cmd.extend(["--candidate", candidate])
        
        output = self._exec_on_available_node(cmd, timeout=30)
        return output is not None
    
    def switchover(self, candidate: str) -> bool:
        """
        Executa switchover planejado
        
        Args:
            candidate: Nome do novo primário
            
        Returns:
            True se sucesso
        """
        output = self._exec_on_available_node(
            ["patronictl", "switchover", "--candidate", candidate, "--force"],
            timeout=30
        )
        return output is not None
    
    def get_cluster_state(self) -> Dict[str, Any]:
        """
        Obtém estado completo do cluster
        
        Returns:
            Dicionário com informações do cluster
        """
        from datetime import datetime
        
        members = self.get_cluster_members()
        
        state = {
            "timestamp": datetime.utcnow().isoformat(),
            "primary": None,
            "replicas": [],
            "failed_nodes": [],
            "total_nodes": 0
        }
        
        if members:
            state["total_nodes"] = len(members)
            for member in members:
                name = member.get("Member")
                role = member.get("Role")
                status = member.get("State")
                
                if role == "Leader":
                    state["primary"] = name
                elif role == "Replica" and status == "streaming":
                    state["replicas"].append(name)
                elif status not in ["running", "streaming"]:
                    state["failed_nodes"].append(name)
        
        return state
    
    def is_cluster_healthy(self) -> bool:
        """
        Verifica se cluster está saudável
        
        Returns:
            True se há um líder e pelo menos 1 réplica
        """
        state = self.get_cluster_state()
        return state["primary"] is not None and len(state["replicas"]) > 0
    
    @staticmethod
    def get_all_patroni_nodes() -> List[str]:
        """
        Obtém lista de todos os nós Patroni do .env
        
        Returns:
            Lista com nomes dos containers Patroni
        """
        return config.patroni_nodes
    
    @staticmethod
    def get_patroni_node_by_index(index: int) -> str:
        """
        Obtém nó Patroni por índice (0, 1, 2)
        
        Args:
            index: Índice do nó (0=patroni1, 1=patroni2, 2=patroni3)
            
        Returns:
            Nome do container
        """
        nodes = config.patroni_nodes
        if 0 <= index < len(nodes):
            return nodes[index]
        raise IndexError(f"Índice {index} inválido. Deve ser 0-{len(nodes)-1}")
