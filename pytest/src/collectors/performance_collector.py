"""
Coletor de métricas de Performance
"""
import subprocess
import re
from typing import Optional, Dict, Any
from src.models.performance_metrics import PerformanceMetrics, LoadTestSummary


class PerformanceCollector:
    """Coletor de métricas de performance usando pgbench"""
    
    def __init__(self, run_id: str):
        self.run_id = run_id
    
    def run_pgbench(
        self,
        test_case: str,
        scenario: str,
        host: str = "localhost",
        port: int = 5432,
        clients: int = 10,
        threads: int = 4,
        duration: int = 60,
        workload: str = "select-only"
    ) -> PerformanceMetrics:
        """
        Executa teste de carga com pgbench
        
        Args:
            test_case: Nome do caso de teste
            scenario: 'baseline' ou 'cluster'
            host: Host do PostgreSQL/PgPool
            port: Porta
            clients: Número de clientes simultâneos
            threads: Número de threads
            duration: Duração do teste em segundos
            workload: Tipo de carga ('select-only', 'simple-update', 'mixed')
            
        Returns:
            PerformanceMetrics com resultados
        """
        metrics = PerformanceMetrics(
            run_id=self.run_id,
            test_case=test_case,
            scenario=scenario,
            clients=clients,
            threads=threads,
            duration_seconds=duration,
            workload_type=workload,
            pgpool_enabled=(scenario == "cluster")
        )
        
        # Monta comando pgbench
        cmd = [
            "pgbench",
            "-h", host,
            "-p", str(port),
            "-U", "postgres",
            "-c", str(clients),
            "-j", str(threads),
            "-T", str(duration),
            "-P", "5",  # Progress a cada 5 segundos
        ]
        
        # Adiciona flag de workload
        if workload == "select-only":
            cmd.append("-S")
        elif workload == "simple-update":
            cmd.append("-N")
        # mixed não precisa de flag especial
        
        cmd.append("postgres")
        
        # Executa pgbench
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=duration + 30
            )
            
            if result.returncode == 0:
                metrics.pgbench_output = result.stdout
                self._parse_pgbench_output(metrics, result.stdout)
            
        except subprocess.TimeoutExpired:
            pass
        except Exception:
            pass
        
        metrics.calculate_metrics()
        return metrics
    
    def _parse_pgbench_output(self, metrics: PerformanceMetrics, output: str):
        """
        Parseia output do pgbench e extrai métricas
        
        Args:
            metrics: Objeto PerformanceMetrics a preencher
            output: Output do pgbench
        """
        # Exemplo de output do pgbench:
        # transaction type: <builtin: select only>
        # scaling factor: 1
        # query mode: simple
        # number of clients: 10
        # number of threads: 4
        # duration: 60 s
        # number of transactions actually processed: 123456
        # latency average = 4.567 ms
        # tps = 2057.600000 (including connections establishing)
        # tps = 2057.700000 (excluding connections establishing)
        
        # TPS including connections
        match = re.search(r'tps = ([\d.]+) \(including connections', output)
        if match:
            metrics.tps_including_connections = float(match.group(1))
            metrics.tps_total = float(match.group(1))
        
        # TPS excluding connections
        match = re.search(r'tps = ([\d.]+) \(excluding connections', output)
        if match:
            metrics.tps_excluding_connections = float(match.group(1))
        
        # Latency average
        match = re.search(r'latency average = ([\d.]+) ms', output)
        if match:
            metrics.latency_avg = float(match.group(1))
        
        # Total transactions
        match = re.search(r'number of transactions actually processed: (\d+)', output)
        if match:
            metrics.total_transactions = int(match.group(1))
        
        # Failed transactions
        match = re.search(r'number of failed transactions: (\d+)', output)
        if match:
            metrics.failed_transactions = int(match.group(1))
        else:
            metrics.failed_transactions = 0
    
    def initialize_pgbench_database(
        self,
        host: str = "localhost",
        port: int = 5432,
        scale: int = 1
    ) -> bool:
        """
        Inicializa database para testes pgbench
        
        Args:
            host: Host do PostgreSQL
            port: Porta
            scale: Fator de escala (1 = ~16MB)
            
        Returns:
            True se sucesso
        """
        cmd = [
            "pgbench",
            "-h", host,
            "-p", str(port),
            "-U", "postgres",
            "-i",
            "-s", str(scale),
            "postgres"
        ]
        
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                timeout=300
            )
            return result.returncode == 0
        except Exception:
            return False
    
    def compare_scenarios(
        self,
        baseline: PerformanceMetrics,
        cluster: PerformanceMetrics
    ) -> LoadTestSummary:
        """
        Compara resultados de baseline vs cluster
        
        Args:
            baseline: Métricas do baseline (single node)
            cluster: Métricas do cluster (com PgPool)
            
        Returns:
            LoadTestSummary com comparação
        """
        summary = LoadTestSummary(
            run_id=self.run_id,
            baseline_tps=baseline.tps_total,
            baseline_latency_avg=baseline.latency_avg,
            cluster_tps=cluster.tps_total,
            cluster_latency_avg=cluster.latency_avg
        )
        
        summary.calculate_comparison()
        return summary
