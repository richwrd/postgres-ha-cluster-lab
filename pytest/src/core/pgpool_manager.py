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
        self.docker = DockerManager()
        
        self.pgpool_container = pgpool_container or config.pgpool_name
        
        self.user = config.postgres_user
        self.password = config.postgres_password
        self.database = config.postgres_db

        self.pgpool_admin_user = config.pgpool_admin_user
        self.pgpool_admin_password = config.pgpool_admin_password
        
    
    def show_pool_nodes(self) -> Optional[str]:
        """
        Mostra status dos nós do pool
        
        Returns:
            Output do comando ou None
        """
        return self.docker.exec_command(
            self.pgpool_container,
            ["psql", "-h", "localhost", "-p", "5432", "-U", self.user, 
             "-d", self.database, "-c", "SHOW POOL_NODES"],
            timeout=10,
            exec_options=["-e", f"PGPASSWORD={self.password}"]
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
             "-U", self.pgpool_admin_user],
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
             "-U", self.pgpool_admin_user, "-n", str(node_id)],
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
             "-U", self.pgpool_admin_user, "-n", str(node_id)],
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

    def attach_down_nodes(self) -> Dict[str, Any]:
        """
        Anexa automaticamente todos os nós marcados como DOWN no pool
        
        Returns:
            Dicionário com resultado das operações:
            - nodes_attached: lista de node_ids anexados com sucesso
            - nodes_failed: lista de node_ids que falhou ao anexar
            - total_down: total de nós DOWN encontrados
        """
        output = self.show_pool_nodes()
        
        result = {
            "nodes_attached": [],
            "nodes_failed": [],
            "total_down": 0
        }
        
        if not output:
            return result
        
        # Parse do output para encontrar nós DOWN
        lines = output.strip().split('\n')
        for line in lines:
            line = line.strip()
            if not line or line.startswith('node_id') or line.startswith('-') or line.startswith('('):
                continue
            
            parts = line.split('|')
            if len(parts) >= 4:
                node_id_str = parts[0].strip()
                status = parts[3].strip()
                
                if status.lower() == 'down':
                    try:
                        node_id = int(node_id_str)
                        result["total_down"] += 1
                        
                        if self.attach_node(node_id):
                            result["nodes_attached"].append(node_id)
                        else:
                            result["nodes_failed"].append(node_id)
                    except ValueError:
                        continue
        
        return result