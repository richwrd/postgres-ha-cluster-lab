"""
Fixtures relacionadas ao cluster
"""
import pytest
from src.core.patroni_manager import PatroniManager
from src.core.postgres_manager import PostgresManager
from src.core.pgpool_manager import PgPoolManager


@pytest.fixture(scope="session")
def patroni_manager():
    """Gerenciador Patroni compartilhado"""
    return PatroniManager()


@pytest.fixture(scope="session")
def postgres_manager():
    """Gerenciador PostgreSQL compartilhado"""
    return PostgresManager()


@pytest.fixture(scope="session")
def pgpool_manager():
    """Gerenciador PgPool compartilhado"""
    return PgPoolManager()


@pytest.fixture
def cluster_healthy(patroni_manager):
    """Verifica se cluster está saudável antes do teste"""
    if not patroni_manager.is_cluster_healthy():
        raise RuntimeError("Cluster não está saudável")
    return True


@pytest.fixture
def get_primary_node(patroni_manager):
    """Retorna função para obter nó primário"""
    return lambda: patroni_manager.get_primary_node()


@pytest.fixture
def get_replica_nodes(patroni_manager):
    """Retorna função para obter nós réplica"""
    return lambda: patroni_manager.get_replica_nodes()


@pytest.fixture
def patroni_switchover(patroni_manager):
    """
    Retorna função para executar switchover controlado
    
    Usage:
        patroni_switchover()  # Patroni escolhe melhor réplica
        patroni_switchover(target='patroni2')  # Target específico
    """
    def _switchover(target=None, force=True):
        return patroni_manager.switchover(target=target, force=force)
    return _switchover


