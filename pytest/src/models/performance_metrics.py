"""
Métricas de Performance (TPS e Latência)
"""
from dataclasses import dataclass, asdict
from typing import Optional, Dict, Any, List


@dataclass
class PerformanceMetrics:
    """Métricas de performance para testes de carga"""
    run_id: str
    test_case: str
    scenario: str  # 'baseline' ou 'cluster'
    
    # Configuração do teste
    clients: int = 1
    threads: int = 1
    duration_seconds: int = 60
    workload_type: str = "mixed"  # 'select-only', 'simple-update', 'mixed'
    
    # Informações do pgbench
    pgbench_version: Optional[str] = None
    transaction_type: Optional[str] = None  # Ex: "<builtin: select only>"
    scaling_factor: Optional[int] = None
    query_mode: Optional[str] = None  # 'simple', 'extended', 'prepared'
    max_tries: Optional[int] = None
    
    # Métricas de TPS (Transactions Per Second)
    tps_total: Optional[float] = None
    tps_including_connections: Optional[float] = None
    tps_excluding_connections: Optional[float] = None
    
    # Métricas de Latência (em ms)
    latency_avg: Optional[float] = None
    latency_stddev: Optional[float] = None
    latency_min: Optional[float] = None
    latency_max: Optional[float] = None
    latency_p50: Optional[float] = None  # Mediana
    latency_p95: Optional[float] = None
    latency_p99: Optional[float] = None
    
    # Métricas de Conexão
    initial_connection_time: Optional[float] = None  # em ms
    
    # Métricas de Transações
    total_transactions: Optional[int] = None
    failed_transactions: Optional[int] = None
    failed_transactions_percent: Optional[float] = None
    success_rate: Optional[float] = None
    
    # Configuração do cluster (para scenario='cluster')
    pgpool_enabled: bool = False
    load_balancing_enabled: bool = False
    num_replicas: Optional[int] = None
    
    # Raw output do pgbench
    pgbench_output: Optional[str] = None
    
    def calculate_metrics(self):
        """Calcula métricas derivadas"""
        if self.total_transactions and self.total_transactions > 0:
            if self.failed_transactions is None:
                self.failed_transactions = 0
            self.success_rate = (
                (self.total_transactions - self.failed_transactions) / 
                self.total_transactions * 100
            )
            # Calcula percentual de falhas se ainda não foi extraído
            if self.failed_transactions_percent is None:
                self.failed_transactions_percent = (
                    self.failed_transactions / self.total_transactions * 100
                )
    
    def to_json(self) -> Dict[str, Any]:
        """Converte para dicionário JSON"""
        return asdict(self)


@dataclass
class LoadTestSummary:
    """Resumo comparativo de testes de carga"""
    run_id: str
    
    # Métricas do baseline (single node)
    baseline_tps: Optional[float] = None
    baseline_latency_avg: Optional[float] = None
    
    # Métricas do cluster (com PgPool)
    cluster_tps: Optional[float] = None
    cluster_latency_avg: Optional[float] = None
    
    # Comparação (%)
    tps_difference_percent: Optional[float] = None
    latency_difference_percent: Optional[float] = None
    
    # Escalabilidade
    scalability_factor: Optional[float] = None  # cluster_tps / baseline_tps
    
    def calculate_comparison(self):
        """Calcula métricas de comparação"""
        if self.baseline_tps and self.cluster_tps:
            self.tps_difference_percent = (
                (self.cluster_tps - self.baseline_tps) / self.baseline_tps * 100
            )
            self.scalability_factor = self.cluster_tps / self.baseline_tps
        
        if self.baseline_latency_avg and self.cluster_latency_avg:
            self.latency_difference_percent = (
                (self.cluster_latency_avg - self.baseline_latency_avg) / 
                self.baseline_latency_avg * 100
            )
    
    def to_json(self) -> Dict[str, Any]:
        """Converte para dicionário JSON"""
        return asdict(self)
