"""
Modelo de dados para métricas de Docker Stats
"""
from dataclasses import dataclass, field
from typing import Dict, List
from datetime import datetime


@dataclass
class ContainerStats:
    """Estatísticas de um container em um momento específico"""
    timestamp: datetime
    cpu_percent: float
    memory_usage_bytes: float
    memory_percent: float
    network_rx_bytes: float
    network_tx_bytes: float
    block_read_bytes: float
    block_write_bytes: float


@dataclass
class ContainerStatsAverage:
    """Estatísticas médias de um container durante um período"""
    container_name: str
    cpu_percent_avg: float
    cpu_percent_max: float
    memory_usage_bytes_avg: float
    memory_usage_bytes_max: float
    memory_percent_avg: float
    memory_percent_max: float
    network_rx_bytes_total: float
    network_tx_bytes_total: float
    block_read_bytes_total: float
    block_write_bytes_total: float
    sample_count: int
    duration_seconds: float


@dataclass
class DockerStatsMetrics:
    """Métricas agregadas de Docker Stats para múltiplos containers"""
    test_name: str
    start_time: datetime
    end_time: datetime
    containers: Dict[str, ContainerStatsAverage] = field(default_factory=dict)
    
    @property
    def duration_seconds(self) -> float:
        """Duração total da coleta"""
        return (self.end_time - self.start_time).total_seconds()
    
    def to_dict(self) -> dict:
        """Converte para dicionário para serialização JSON"""
        return {
            'test_name': self.test_name,
            'start_time': self.start_time.isoformat(),
            'end_time': self.end_time.isoformat(),
            'duration_seconds': self.duration_seconds,
            'containers': {
                name: {
                    'container_name': stats.container_name,
                    'cpu_percent_avg': round(stats.cpu_percent_avg, 2),
                    'cpu_percent_max': round(stats.cpu_percent_max, 2),
                    'memory_usage_mb_avg': round(stats.memory_usage_bytes_avg / (1024**2), 2),
                    'memory_usage_mb_max': round(stats.memory_usage_bytes_max / (1024**2), 2),
                    'memory_percent_avg': round(stats.memory_percent_avg, 2),
                    'memory_percent_max': round(stats.memory_percent_max, 2),
                    'network_rx_mb_total': round(stats.network_rx_bytes_total / (1024**2), 2),
                    'network_tx_mb_total': round(stats.network_tx_bytes_total / (1024**2), 2),
                    'block_read_mb_total': round(stats.block_read_bytes_total / (1024**2), 2),
                    'block_write_mb_total': round(stats.block_write_bytes_total / (1024**2), 2),
                    'sample_count': stats.sample_count,
                    'duration_seconds': round(stats.duration_seconds, 2)
                }
                for name, stats in self.containers.items()
            }
        }
