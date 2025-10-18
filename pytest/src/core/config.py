"""
Gerenciador de configuração - Lê variáveis do .env
"""
import os
from pathlib import Path
from typing import Dict, Optional


class Config:
    """Gerencia configurações do projeto lendo .env da raiz"""
    
    _instance = None
    _config: Dict[str, str] = {}
    
    def __new__(cls):
        """Singleton - garante única instância"""
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._load_env()
        return cls._instance
    
    def _parse_env_file(self, env_file: Path):
        """
        Parseia um arquivo .env e adiciona ao _config
        
        Args:
            env_file: Caminho para o arquivo .env
        """
        if not env_file.exists():
            return  # Ignora arquivos que não existem
        
        with open(env_file, 'r') as f:
            for line in f:
                line = line.strip()
                
                # Ignora comentários e linhas vazias
                if not line or line.startswith('#') or line.startswith('='):
                    continue
                
                # Parseia KEY=VALUE
                if '=' in line:
                    key, value = line.split('=', 1)
                    key = key.strip()
                    value = value.strip()
                    
                    # Remove aspas se existirem
                    if value.startswith('"') and value.endswith('"'):
                        value = value[1:-1]
                    elif value.startswith("'") and value.endswith("'"):
                        value = value[1:-1]
                    
                    # Expande variáveis ${VAR}
                    if '${' in value:
                        for k, v in self._config.items():
                            value = value.replace(f'${{{k}}}', v)
                    
                    self._config[key] = value
    
    def _load_env(self):
        """Carrega variáveis de todos os arquivos .env do projeto"""
        # Raiz do projeto (2 níveis acima de pytest/src/)
        project_root = Path(__file__).parent.parent.parent.parent
        
        # Define os arquivos .env na ordem de carregamento
        env_files = [
            project_root / ".env",                                    # ENV_ROOT
            project_root / "infra/patroni-postgres/config/.patroni.env",  # ENV_PATRONI
            project_root / "infra/pgpool/config/.pgpool.env",         # ENV_PGPOOL
        ]
        
        # Verifica se pelo menos o .env principal existe
        if not env_files[0].exists():
            raise FileNotFoundError(
                f"Arquivo .env não encontrado em: {env_files[0]}\n"
                f"Certifique-se de que o .env existe na raiz do projeto."
            )
        
        # Carrega todos os arquivos .env
        for env_file in env_files:
            self._parse_env_file(env_file)
    
    def get(self, key: str, default: Optional[str] = None) -> Optional[str]:
        """
        Obtém valor de uma variável do .env
        
        Args:
            key: Nome da variável
            default: Valor padrão se não encontrada
            
        Returns:
            Valor da variável ou default
        """
        return self._config.get(key, default)
    
    def require(self, key: str) -> str:
        """
        Obtém valor obrigatório (lança exceção se não existir)
        
        Args:
            key: Nome da variável
            
        Returns:
            Valor da variável
            
        Raises:
            ValueError: Se variável não existe
        """
        value = self._config.get(key)
        if value is None:
            raise ValueError(f"Variável obrigatória '{key}' não encontrada no .env")
        return value
    
    # Propriedades de conveniência para nomes de containers
    
    @property
    def etcd1_name(self) -> str:
        """Nome do container ETCD 1"""
        return self.get('ETCD1_NAME', 'etcd-1')
    
    @property
    def etcd2_name(self) -> str:
        """Nome do container ETCD 2"""
        return self.get('ETCD2_NAME', 'etcd-2')
    
    @property
    def etcd3_name(self) -> str:
        """Nome do container ETCD 3"""
        return self.get('ETCD3_NAME', 'etcd-3')
    
    @property
    def patroni1_name(self) -> str:
        """Nome do container Patroni 1"""
        return self.get('PATRONI1_NAME', 'patroni-postgres-1')
    
    @property
    def patroni2_name(self) -> str:
        """Nome do container Patroni 2"""
        return self.get('PATRONI2_NAME', 'patroni-postgres-2')
    
    @property
    def patroni3_name(self) -> str:
        """Nome do container Patroni 3"""
        return self.get('PATRONI3_NAME', 'patroni-postgres-3')
    
    @property
    def pgpool_name(self) -> str:
        """Nome do container PgPool"""
        return self.get('PGPOOL_NAME', 'pgpool')
    
    @property
    def patroni_nodes(self) -> list:
        """Lista com todos os nós Patroni"""
        return [
            self.patroni1_name,
            self.patroni2_name,
            self.patroni3_name
        ]
    
    @property
    def etcd_nodes(self) -> list:
        """Lista com todos os nós ETCD"""
        return [
            self.etcd1_name,
            self.etcd2_name,
            self.etcd3_name
        ]
    
    @property
    def all_containers(self) -> list:
        """Lista com todos os containers do cluster"""
        return self.patroni_nodes + self.etcd_nodes + [self.pgpool_name]
    
    # Propriedades de conveniência para credenciais do PostgreSQL/Patroni
    
    @property
    def postgres_user(self) -> str:
        """Usuário do PostgreSQL"""
        return self.get('TEST_DB_USERNAME', 'postgres')
    
    @property
    def postgres_password(self) -> str:
        """Senha do PostgreSQL"""
        return self.get('TEST_DB_PASSWORD', 'postgres')
    
    @property
    def postgres_db(self) -> str:
        """Nome do banco de dados"""
        return self.get('TEST_DB_NAME', 'postgres')
    
    @property
    def replication_user(self) -> str:
        """Usuário de replicação"""
        return self.get('PATRONI_REPLICATION_USERNAME', 'replicator')
    
    @property
    def replication_password(self) -> str:
        """Senha do usuário de replicação"""
        return self.get('PATRONI_REPLICATION_PASSWORD', 'replicator')
    
    # Propriedades de conveniência para PgPool
    
    @property
    def pgpool_admin_user(self) -> str:
        """Usuário admin do PgPool"""
        return self.get('PGPOOL_PCP_USER', 'admin')
    
    @property
    def pgpool_admin_password(self) -> str:
        """Senha do admin do PgPool"""
        return self.get('PGPOOL_PCP_PASSWORD', 'admin')
    
    def __repr__(self) -> str:
        """Representação para debug"""
        return (
            f"Config(\n"
            f"  patroni_nodes={self.patroni_nodes},\n"
            f"  etcd_nodes={self.etcd_nodes},\n"
            f"  pgpool={self.pgpool_name}\n"
            f")"
        )


# Instância global (Singleton)
config = Config()
