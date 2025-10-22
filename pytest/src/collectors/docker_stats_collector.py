"""
Coletor de estatísticas do Docker durante execução de testes
"""
import time
import threading
from datetime import datetime
from typing import List, Dict, Optional
from collections import defaultdict

from ..core.docker_manager import DockerManager
from ..models.docker_stats_metrics import (
    ContainerStats,
    ContainerStatsAverage,
    DockerStatsMetrics
)


class DockerStatsCollector:
    """
    Coleta estatísticas de containers Docker durante a execução de testes.
    
    Funciona em background thread, coletando métricas em intervalos regulares
    e calculando médias ao final.
    """
    
    def __init__(
        self,
        container_names: List[str],
        interval_seconds: float = 2.0,
        debug: bool = False
    ):
        """
        Inicializa o coletor
        
        Args:
            container_names: Lista de nomes dos containers a monitorar
            interval_seconds: Intervalo entre coletas em segundos
            debug: Se True, exibe dados brutos coletados
        """
        self.container_names = container_names
        self.interval_seconds = interval_seconds
        self.debug = debug
        
        # Armazenamento de amostras
        self.samples: Dict[str, List[ContainerStats]] = defaultdict(list)
        
        # Controle de coleta
        self._collecting = False
        self._thread: Optional[threading.Thread] = None
        self._start_time: Optional[datetime] = None
        self._end_time: Optional[datetime] = None
    
    def start(self) -> None:
        """Inicia a coleta de estatísticas"""
        if self._collecting:
            return
        
        self._collecting = True
        self._start_time = datetime.now()
        self._thread = threading.Thread(target=self._collect_loop, daemon=True)
        self._thread.start()
        print(f"📊 Coleta de Docker Stats iniciada para: {', '.join(self.container_names)}")
    
    def stop(self) -> None:
        """Para a coleta de estatísticas"""
        if not self._collecting:
            return
        
        self._collecting = False
        self._end_time = datetime.now()
        
        if self._thread:
            self._thread.join(timeout=5.0)
        
        print(f"📊 Coleta de Docker Stats finalizada ({len(self.samples)} containers, "
              f"~{sum(len(s) for s in self.samples.values())} amostras)")
    
    def _collect_loop(self) -> None:
        """Loop de coleta em background"""
        while self._collecting:
            self._collect_sample()
            time.sleep(self.interval_seconds)
    
    def _collect_sample(self) -> None:
        """Coleta uma amostra de estatísticas"""
        stats = DockerManager.get_stats(self.container_names)
        if not stats:
            return
        
        timestamp = datetime.now()
        
        for container_name, data in stats.items():
            # Parse network I/O (formato: "1.2MB / 3.4MB")
            net_rx, net_tx = 0.0, 0.0
            if '/' in data['network_io']:
                parts = data['network_io'].split('/')
                if len(parts) == 2:
                    net_rx = DockerManager.parse_bytes(parts[0].strip())
                    net_tx = DockerManager.parse_bytes(parts[1].strip())
            
            # Parse block I/O (formato: "5.6MB / 7.8MB")
            block_read, block_write = 0.0, 0.0
            if '/' in data['block_io']:
                parts = data['block_io'].split('/')
                if len(parts) == 2:
                    block_read = DockerManager.parse_bytes(parts[0].strip())
                    block_write = DockerManager.parse_bytes(parts[1].strip())
            
            # Parse memory usage (formato: "1.5GiB / 16GiB")
            mem_used = 0.0
            if '/' in data['memory_usage']:
                mem_used = DockerManager.parse_bytes(
                    data['memory_usage'].split('/')[0].strip()
                )
            
            sample = ContainerStats(
                timestamp=timestamp,
                cpu_percent=data['cpu_percent'],
                memory_usage_bytes=mem_used,
                memory_percent=data['memory_percent'],
                network_rx_bytes=net_rx,
                network_tx_bytes=net_tx,
                block_read_bytes=block_read,
                block_write_bytes=block_write
            )
            
            self.samples[container_name].append(sample)
    
    def get_metrics(self, test_name: str) -> DockerStatsMetrics:
        """
        Calcula e retorna as métricas agregadas
        
        Args:
            test_name: Nome do teste
            
        Returns:
            Métricas agregadas
        """
        if not self._start_time or not self._end_time:
            raise ValueError("Coleta não foi iniciada/finalizada corretamente")
        
        metrics = DockerStatsMetrics(
            test_name=test_name,
            start_time=self._start_time,
            end_time=self._end_time
        )
        
        for container_name, samples in self.samples.items():
            if not samples:
                continue
            
            # Calcula médias e máximos
            cpu_values = [s.cpu_percent for s in samples]
            mem_bytes_values = [s.memory_usage_bytes for s in samples]
            mem_percent_values = [s.memory_percent for s in samples]
            
            # Network e Block I/O são cumulativos, pegamos os últimos valores
            last_sample = samples[-1]
            first_sample = samples[0]
            
            avg_stats = ContainerStatsAverage(
                container_name=container_name,
                cpu_percent_avg=sum(cpu_values) / len(cpu_values),
                cpu_percent_max=max(cpu_values),
                memory_usage_bytes_avg=sum(mem_bytes_values) / len(mem_bytes_values),
                memory_usage_bytes_max=max(mem_bytes_values),
                memory_percent_avg=sum(mem_percent_values) / len(mem_percent_values),
                memory_percent_max=max(mem_percent_values),
                network_rx_bytes_total=last_sample.network_rx_bytes,
                network_tx_bytes_total=last_sample.network_tx_bytes,
                block_read_bytes_total=last_sample.block_read_bytes,
                block_write_bytes_total=last_sample.block_write_bytes,
                sample_count=len(samples),
                duration_seconds=(last_sample.timestamp - first_sample.timestamp).total_seconds()
            )
            
            metrics.containers[container_name] = avg_stats
        
        return metrics
    
    def reset(self) -> None:
        """Reseta as amostras coletadas"""
        self.samples.clear()
        self._start_time = None
        self._end_time = None
