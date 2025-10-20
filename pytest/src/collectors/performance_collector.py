"""
Coletor de métricas de Performance
"""
import subprocess
import re
from typing import Optional, Dict, Any
from src.models.performance_metrics import PerformanceMetrics, LoadTestSummary
from src.core.docker_manager import DockerManager


class PerformanceCollector:
    """Coletor de métricas de performance usando pgbench"""
    
    def __init__(self, run_id: str):
        self.run_id = run_id
    
    def run_pgbench(
        self,
        test_case: str,
        scenario: str,
        container_name: str = "pgbench-client",
        host: str = "localhost",
        port: int = 5432,
        user: str = "postgres",
        password: str = "postgres",
        database: str = "postgres",
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
            container_name: Nome do container onde executar pgbench
            host: Host do PostgreSQL/PgPool
            port: Porta
            user: Usuário do banco
            password: Senha do usuário
            database: Nome do banco de dados
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
        
        # Monta comando pgbench interno
        pgbench_cmd = [
            "pgbench",
            "-h", host,
            "-p", str(port),
            "-U", user,
            "-c", str(clients),
            "-j", str(threads),
            "-T", str(duration),
            "-P", "5",  # Progress a cada 5 segundos
        ]
        
        # Adiciona flag de workload
        if workload == "select-only":
            pgbench_cmd.append("-S")
        elif workload == "simple-update":
            pgbench_cmd.append("-N")
        # mixed não precisa de flag especial
        
        pgbench_cmd.append(database)
        
        # Executa pgbench usando DockerManager
        print(f"\n🔧 Executando pgbench: -h {host} -p {port} -c {clients} -j {threads} -T {duration}s")
        
        result = DockerManager.exec_command(
            container_name=container_name,
            command=pgbench_cmd,
            exec_options=["-e", f"PGPASSWORD={password}"],
            timeout=duration + 30
        )
        
        if result:
            metrics.pgbench_output = result
            print(f"\n📊 Output do pgbench:\n{result}")
            self._parse_pgbench_output(metrics, result)
        else:
            print(f"❌ Erro ao executar pgbench")
        
        metrics.calculate_metrics()
        
        # Garante valores padrão para evitar None
        if metrics.tps_total is None:
            metrics.tps_total = 0.0
        if metrics.tps_excluding_connections is None:
            metrics.tps_excluding_connections = 0.0
        if metrics.latency_avg is None:
            metrics.latency_avg = 0.0
        if metrics.total_transactions is None:
            metrics.total_transactions = 0
        if metrics.failed_transactions is None:
            metrics.failed_transactions = 0
        if metrics.success_rate is None:
            metrics.success_rate = 0.0
            
        return metrics
    
    def _parse_pgbench_output(self, metrics: PerformanceMetrics, output: str):
        """
        Parseia output do pgbench e extrai métricas
        
        Args:
            metrics: Objeto PerformanceMetrics a preencher
            output: Output do pgbench
        """
        
        # Versão do pgbench
        # Ex: pgbench (17.6 (Debian 17.6-2.pgdg13+1))
        match = re.search(r'pgbench \(([^)]+)\)', output)
        if match:
            metrics.pgbench_version = match.group(1)
        
        # Transaction type
        # Ex: transaction type: <builtin: select only>
        match = re.search(r'transaction type: (.+)', output)
        if match:
            metrics.transaction_type = match.group(1).strip()
        
        # Scaling factor
        # Ex: scaling factor: 10
        match = re.search(r'scaling factor: (\d+)', output)
        if match:
            metrics.scaling_factor = int(match.group(1))
        
        # Query mode
        # Ex: query mode: simple
        match = re.search(r'query mode: (\w+)', output)
        if match:
            metrics.query_mode = match.group(1)
        
        # Maximum number of tries
        # Ex: maximum number of tries: 1
        match = re.search(r'maximum number of tries: (\d+)', output)
        if match:
            metrics.max_tries = int(match.group(1))
        
        # TPS without initial connection time (formato novo - pgbench >= 14)
        match = re.search(r'tps = ([\d.]+) \(without initial connection time\)', output)
        if match:
            tps_value = float(match.group(1))
            metrics.tps_excluding_connections = tps_value
            # Se não temos tps_total ainda, usa este valor
            if metrics.tps_total is None or metrics.tps_total == 0.0:
                metrics.tps_total = tps_value
        
        # TPS including connections (formato antigo)
        match = re.search(r'tps = ([\d.]+) \(including connections', output)
        if match:
            metrics.tps_including_connections = float(match.group(1))
            if metrics.tps_total is None or metrics.tps_total == 0.0:
                metrics.tps_total = float(match.group(1))
        
        # TPS excluding connections (formato antigo)
        match = re.search(r'tps = ([\d.]+) \(excluding connections', output)
        if match:
            metrics.tps_excluding_connections = float(match.group(1))
        
        # Latency average
        # Ex: latency average = 0.423 ms
        match = re.search(r'latency average = ([\d.]+) ms', output)
        if match:
            metrics.latency_avg = float(match.group(1))
        
        # Latency stddev
        # Ex: latency stddev = 0.248 ms
        match = re.search(r'latency stddev = ([\d.]+) ms', output)
        if match:
            metrics.latency_stddev = float(match.group(1))
        
        # Initial connection time
        # Ex: initial connection time = 84.418 ms
        match = re.search(r'initial connection time = ([\d.]+) ms', output)
        if match:
            metrics.initial_connection_time = float(match.group(1))
        
        # Total transactions
        # Ex: number of transactions actually processed: 1402337
        match = re.search(r'number of transactions actually processed: (\d+)', output)
        if match:
            metrics.total_transactions = int(match.group(1))
        
        # Failed transactions com percentual
        # Ex: number of failed transactions: 0 (0.000%)
        match = re.search(r'number of failed transactions: (\d+) \(([\d.]+)%\)', output)
        if match:
            metrics.failed_transactions = int(match.group(1))
            metrics.failed_transactions_percent = float(match.group(2))
        else:
            # Formato antigo sem percentual
            match = re.search(r'number of failed transactions: (\d+)', output)
            if match:
                metrics.failed_transactions = int(match.group(1))
            else:
                metrics.failed_transactions = 0
    
    def initialize_pgbench_database(
        self,
        container_name: str = "pgbench-client",
        host: str = "localhost",
        port: int = 5432,
        user: str = "postgres",
        password: str = "postgres",
        database: str = "postgres",
        scale: int = 1
    ) -> bool:
        """
        Inicializa database para testes pgbench.
        Verifica se já foi inicializado antes de executar.
        
        Args:
            container_name: Nome do container onde executar pgbench
            host: Host do PostgreSQL
            port: Porta
            user: Usuário do banco
            password: Senha do usuário
            database: Nome do banco de dados
            scale: Fator de escala (1 = ~16MB)
            
        Returns:
            True se sucesso
        """
        # Verifica se database já foi inicializado (tabela pgbench_accounts existe)
        print(f"\n🔍 Verificando se database pgbench já está inicializado...")
        
        check_query = "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'pgbench_accounts');"
        check_cmd = [
            "psql",
            "-h", host,
            "-p", str(port),
            "-U", user,
            "-d", database,
            "-tAc", check_query
        ]
        
        check_result = DockerManager.exec_command(
            container_name=container_name,
            command=check_cmd,
            exec_options=["-e", f"PGPASSWORD={password}"],
            timeout=10
        )
        
        if check_result and check_result.strip() == 't':
            print(f"✅ Database pgbench já inicializado (tabela pgbench_accounts existe)")
            print(f"   Pulando inicialização para economizar tempo")
            return True
        
        print(f"⚠️  Database não inicializado ou tabela não encontrada")
        print(f"\n🔧 Inicializando database pgbench (scale={scale})...")
        print(f"   Isso pode levar alguns minutos para databases grandes...")
        
        # Monta comando pgbench
        pgbench_cmd = [
            "pgbench",
            "-h", host,
            "-p", str(port),
            "-U", user,
            "-i",
            "-s", str(scale),
            database
        ]
        
        print(f"🔧 Executando: pgbench -h {host} -p {port} -U {user} -i -s {scale} {database}")
        
        try:
            # Executa inicialização usando DockerManager
            init_result = DockerManager.exec_command(
                container_name=container_name,
                command=pgbench_cmd,
                exec_options=["-e", f"PGPASSWORD={password}"],
                timeout=7200  # 2 horas para databases muito grandes
            )
            
            if init_result is not None:
                print(f"\n✅ Database inicializado com sucesso!")
                print(f"   Output completo:\n{init_result}")
                
                return True
            else:
                print(f"\n❌ Erro ao inicializar pgbench - comando retornou None")
                return False
                
        except Exception as e:
            print(f"\n❌ ERRO ao inicializar database pgbench:")
            print(f"   Tipo: {type(e).__name__}")
            print(f"   Mensagem: {str(e)}")
            import traceback
            print(f"   Traceback completo:\n{traceback.format_exc()}")
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
