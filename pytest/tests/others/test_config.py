"""
Testes para validar configuração do .env
"""
import pytest
from src.core import config


def test_config_loads_env():
    """Testa se .env foi carregado corretamente"""
    assert config is not None
    assert config.patroni1_name is not None


def test_patroni_node_names():
    """Valida nomes dos nós Patroni"""
    assert config.patroni1_name == "patroni-postgres-1"
    assert config.patroni2_name == "patroni-postgres-2"
    assert config.patroni3_name == "patroni-postgres-3"


def test_etcd_node_names():
    """Valida nomes dos nós ETCD"""
    assert config.etcd1_name == "etcd-1"
    assert config.etcd2_name == "etcd-2"
    assert config.etcd3_name == "etcd-3"


def test_pgpool_name():
    """Valida nome do PgPool"""
    assert config.pgpool_name == "pgpool"


def test_patroni_nodes_list():
    """Valida lista de nós Patroni"""
    nodes = config.patroni_nodes
    assert len(nodes) == 3
    assert "patroni-postgres-1" in nodes
    assert "patroni-postgres-2" in nodes
    assert "patroni-postgres-3" in nodes


def test_all_containers_list():
    """Valida lista completa de containers"""
    containers = config.all_containers
    assert len(containers) == 7  # 3 patroni + 3 etcd + 1 pgpool
    assert "patroni-postgres-1" in containers
    assert "etcd-1" in containers
    assert "pgpool" in containers


def test_config_repr():
    """Testa representação do config"""
    repr_str = repr(config)
    assert "patroni_nodes" in repr_str
    assert "etcd_nodes" in repr_str
    assert "pgpool" in repr_str
