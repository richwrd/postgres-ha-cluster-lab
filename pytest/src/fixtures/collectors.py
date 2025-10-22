"""
Fixtures de collectors
"""
import pytest
from typing import List
from src.collectors.rto_collector import RTOCollector
from src.collectors.rpo_collector import RPOCollector
from src.collectors.performance_collector import PerformanceCollector
from src.collectors.docker_stats_collector import DockerStatsCollector


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


@pytest.fixture
def docker_stats_collector(request):
    """
    Coletor de estatísticas Docker que monitora containers durante o teste.
    
    Uso:
        @pytest.mark.monitor_containers(["container1", "container2"])
        def test_example(docker_stats_collector):
            # Inicia coleta automaticamente
            # ... executa teste ...
            # Para coleta automaticamente
            metrics = docker_stats_collector.get_metrics("test_example")
    
    Ou manualmente:
        def test_example(docker_stats_collector):
            collector = docker_stats_collector(["container1"])
            collector.start()
            # ... executa teste ...
            collector.stop()
            metrics = collector.get_metrics("test_example")
    """
    # Verifica se há marcador com lista de containers
    marker = request.node.get_closest_marker("monitor_containers")
    
    if marker:
        # Modo automático: usa containers do marcador
        container_names = marker.args[0] if marker.args else []
        interval = marker.kwargs.get('interval', 2.0)
        
        collector = DockerStatsCollector(container_names, interval_seconds=interval)
        collector.start()
        
        yield collector
        
        collector.stop()
    else:
        # Modo manual: retorna factory function
        def _create_collector(container_names: List[str], interval: float = 2.0):
            return DockerStatsCollector(container_names, interval_seconds=interval)
        
        yield _create_collector
