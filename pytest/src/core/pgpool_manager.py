"""
Gerenciador de operações PgPool-II
"""
from typing import Optional, Dict, Any
from .docker_manager import DockerManager
from .config import config


class PgPoolManager:
    """Gerencia operações com PgPool-II"""
    
    def __init__(self, pgpool_container: Optional[str] = None):
        """
        Args:
            pgpool_container: Nome do container PgPool. Se None, usa o do .env
        """
        self.pgpool_container = pgpool_container or config.pgpool_name
        self.docker = DockerManager()
    
    def show_pool_nodes(self) -> Optional[str]:
        """
        Mostra status dos nós do pool
        
        Returns:
            Output do comando ou None
        """
        return self.docker.exec_command(
            self.pgpool_container,
            ["psql", "-h", "localhost", "-p", "9999", "-U", "postgres", 
             "-c", "SHOW POOL_NODES"],
            timeout=10
        )
    
    def reload_config(self) -> bool:
        """
        Recarrega configuração do PgPool
        
        Returns:
            True se sucesso
        """
        output = self.docker.exec_command(
            self.pgpool_container,
            ["pcp_reload_config", "-h", "localhost", "-p", "9898", 
             "-U", "postgres"],
            timeout=10
        )
        return output is not None
    
    def attach_node(self, node_id: int) -> bool:
        """
        Anexa um nó ao pool
        
        Args:
            node_id: ID do nó (0, 1, 2, ...)
            
        Returns:
            True se sucesso
        """
        output = self.docker.exec_command(
            self.pgpool_container,
            ["pcp_attach_node", "-h", "localhost", "-p", "9898",
             "-U", "postgres", "-n", str(node_id)],
            timeout=10
        )
        return output is not None
    
    def detach_node(self, node_id: int) -> bool:
        """
        Desanexa um nó do pool
        
        Args:
            node_id: ID do nó (0, 1, 2, ...)
            
        Returns:
            True se sucesso
        """
        output = self.docker.exec_command(
            self.pgpool_container,
            ["pcp_detach_node", "-h", "localhost", "-p", "9898",
             "-U", "postgres", "-n", str(node_id)],
            timeout=10
        )
        return output is not None
    
    def get_pool_status(self) -> Dict[str, Any]:
        """
        Obtém status do pool (simplificado)
        
        Returns:
            Dicionário com informações do pool
        """
        from datetime import datetime
        
        output = self.show_pool_nodes()
        
        status = {
            "timestamp": datetime.utcnow().isoformat(),
            "is_available": output is not None,
            "raw_output": output
        }
        
        return status
