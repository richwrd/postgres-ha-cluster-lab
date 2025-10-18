"""
Fixtures de collectors
"""
import pytest
from src.collectors.rto_collector import RTOCollector
from src.collectors.rpo_collector import RPOCollector
from src.collectors.performance_collector import PerformanceCollector


@pytest.fixture
def rto_collector(run_id):
    """Coletor de métricas RTO"""
    return RTOCollector(run_id)


@pytest.fixture
def rpo_collector(run_id):
    """Coletor de métricas RPO"""
    return RPOCollector(run_id)


@pytest.fixture
def performance_collector(run_id):
    """Coletor de métricas de performance"""
    return PerformanceCollector(run_id)
