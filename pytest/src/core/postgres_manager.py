"""
Gerenciador de conexões PostgreSQL
"""
import psycopg2
import time
from typing import Optional, Tuple, Any
from contextlib import contextmanager
from .config import config


class PostgresManager:
    """Gerencia conexões e operações com PostgreSQL"""
    
    def __init__(
        self,
        host: Optional[str] = None,
        port: Optional[int] = None,
        user: Optional[str] = None,
        password: Optional[str] = None,
        database: Optional[str] = None
    ):
        """
        Args:
            host: Host do PostgreSQL (padrão: localhost para pytest externo)
            port: Porta do PostgreSQL (padrão: config.pgpool_port)
            user: Usuário (padrão: config.postgres_user)
            password: Senha (padrão: config.postgres_password)
            database: Database padrão (padrão: config.postgres_db)
        """
        # Usa localhost por padrão pois pytest roda no host, não no Docker
        self.host = host or "localhost"
        self.port = port or config.pgpool_port
        self.user = user or config.postgres_user
        self.password = password or config.postgres_password
        self.database = database or config.postgres_db
    
    @contextmanager
    def get_connection(self, timeout: int = 3):
        """
        Context manager para conexão PostgreSQL
        
        Args:
            timeout: Timeout de conexão
            
        Yields:
            Conexão psycopg2
        """
        conn = None
        try:
            conn = psycopg2.connect(
                host=self.host,
                port=self.port,
                user=self.user,
                password=self.password,
                database=self.database,
                connect_timeout=timeout
            )
            yield conn
        finally:
            if conn:
                conn.close()
    
    def is_available(self, timeout: int = 3) -> bool:
        """
        Verifica se PostgreSQL está disponível
        
        Args:
            timeout: Timeout em segundos
            
        Returns:
            True se disponível
        """
        try:
            with self.get_connection(timeout) as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT 1")
                result = cursor.fetchone()
                cursor.close()
                return result is not None
        except Exception as e:
            # print(f"    [DEBUG] Conexão falhou: {type(e).__name__}: {e}")
            return False
        
    def wait_until_available(self, max_wait: int = 60, check_interval: float = 0.1) -> bool:
        """
        Aguarda até que PostgreSQL esteja disponível
        
        Args:
            max_wait: Tempo máximo de espera (segundos)
            check_interval: Intervalo entre verificações (segundos)
            
        Returns:
            True se ficou disponível, False se timeout
        """
        start_time = time.time()
        attempts = 0
        
        while time.time() - start_time < max_wait:
            attempts += 1
            if self.is_available():
                elapsed = time.time() - start_time
                print(f"    ✓ PostgreSQL disponível após {elapsed:.2f}s ({attempts} tentativas)")
                return True
            
            time.sleep(check_interval)
        
        print(f"    ❌ PostgreSQL não ficou disponível após {max_wait}s ({attempts} tentativas)")
        return False
    
    def execute_query(self, query: str, params: Optional[Tuple] = None) -> Optional[Any]:
        """
        Executa query SELECT
        
        Args:
            query: Query SQL
            params: Parâmetros da query
            
        Returns:
            Resultado da query ou None se falhar
        """
        try:
            with self.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(query, params)
                result = cursor.fetchall()
                cursor.close()
                return result
        except Exception:
            return None
    
    def execute_write(self, query: str, params: Optional[Tuple] = None) -> bool:
        """
        Executa query de escrita (INSERT, UPDATE, DELETE)
        
        Args:
            query: Query SQL
            params: Parâmetros da query
            
        Returns:
            True se sucesso
        """
        try:
            with self.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(query, params)
                conn.commit()
                cursor.close()
                return True
        except Exception:
            return False
    
    def get_replication_lag(self) -> Optional[int]:
        """
        Obtém lag de replicação em bytes (em uma réplica)
        
        Returns:
            Lag em bytes ou None
        """
        query = """
        SELECT 
            CASE 
                WHEN pg_is_in_recovery() THEN 
                    pg_wal_lsn_diff(pg_last_wal_replay_lsn(), '0/0')
                ELSE NULL 
            END as replay_lag
        """
        result = self.execute_query(query)
        if result and result[0][0] is not None:
            return int(result[0][0])
        return None
    
    def create_test_table(self, table_name: str = "rto_test") -> bool:
        """
        Cria tabela de teste
        
        Args:
            table_name: Nome da tabela
            
        Returns:
            True se sucesso
        """
        query = f"""
        CREATE TABLE IF NOT EXISTS {table_name} (
            id SERIAL PRIMARY KEY,
            data TEXT,
            created_at TIMESTAMP DEFAULT NOW()
        )
        """
        return self.execute_write(query)
    
    def insert_test_data(self, table_name: str = "rto_test", data: str = "test") -> Optional[int]:
        """
        Insere dado de teste e retorna o ID
        
        Args:
            table_name: Nome da tabela
            data: Dado a inserir
            
        Returns:
            ID do registro inserido ou None
        """
        query = f"INSERT INTO {table_name} (data) VALUES (%s) RETURNING id"
        try:
            with self.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(query, (data,))
                result = cursor.fetchone()
                conn.commit()
                cursor.close()
                return result[0] if result else None
        except Exception:
            return None
        
    def drop_test_table(self, table_name: str = "rto_test") -> bool:
        """
        Remove tabela de teste
        
        Args:
            table_name: Nome da tabela
            
        Returns:
            True se sucesso
        """
        query = f"DROP TABLE IF EXISTS {table_name}"
        return self.execute_write(query)
    
    def count_records(self, table_name: str = "rto_test") -> Optional[int]:
        """
        Conta registros em uma tabela
        
        Args:
            table_name: Nome da tabela
            
        Returns:
            Número de registros ou None
        """
        query = f"SELECT COUNT(*) FROM {table_name}"
        result = self.execute_query(query)
        if result:
            return result[0][0]
        return None
