"""
Teste de Performance - Baseline (Single Node)
"""
import pytest

# Configurações centralizadas
class BaselineConfig:
    """Configurações compartilhadas entre fixture e testes"""
    
    # Conexão
    CONTAINER_NAME = "pgbench-client"
    HOST = "postgres-baseline"
    PORT = 5432
    USER = "postgres"
    PASSWORD = "postgres"
    DATABASE = "postgres"
    SCENARIO = "baseline"
    
    # Carga
    THREADS = 8
    DURATION = 60
    SCALE = 2200  # ~32GB (DEVE SER O DOBRO DA QT DE RAM DO SISTEMA)

@pytest.mark.baseline_select_only
class TestPerformanceBaseline:
    
    # Herda configurações da classe centralizada
    CONTAINER_NAME = BaselineConfig.CONTAINER_NAME
    HOST = BaselineConfig.HOST
    PORT = BaselineConfig.PORT
    USER = BaselineConfig.USER
    PASSWORD = BaselineConfig.PASSWORD
    DATABASE = BaselineConfig.DATABASE
    SCENARIO = BaselineConfig.SCENARIO
    THREADS = BaselineConfig.THREADS
    DURATION = BaselineConfig.DURATION
    SCALE = BaselineConfig.SCALE
    
    @pytest.mark.parametrize("client_count", [10, 20, 40, 80, 120, 160, 200])
    def test_baseline_select_only(
        self,
        client_count,
        performance_collector,
        performance_writer_baseline
    ):
        """
        Teste de Performance (Baseline) - Escalabilidade
        
        Cenário 1: PostgreSQL standalone
        Carga: SELECT-only (leitura)
        
        Parâmetros pgbench:
        - Clientes: parametrizado (10, 20, 40, 80, 120, 160, 200)
        - Threads: 8
        - Duração: 60s
        - Workload: select-only
        """
        print("\n" + "="*70)
        print(f"TESTE DE PERFORMANCE - BASELINE (SELECT-ONLY) - {client_count} CLIENTES")
        print("="*70)

        print("\n[1/1] Inicializando database pgbench (32GB)...")
        inicialized = self._initialize_database_once(performance_collector)

        # Executa teste de carga (database já foi inicializado pela fixture)
        print("\n[2/2] Executando teste de carga...")
        print(f"  Clientes: {client_count}, Threads: {self.THREADS}, Duração: {self.DURATION}s")
        print(f"  Database: 32GB (scale={self.SCALE})")
        print("  Workload: SELECT-only (leitura)")
        
        metrics = performance_collector.run_pgbench(
            test_case=f"baseline_select_only_{client_count}clients",
            scenario=self.SCENARIO,
            container_name=self.CONTAINER_NAME,
            host=self.HOST,
            port=self.PORT,
            user=self.USER,
            password=self.PASSWORD,
            database=self.DATABASE,
            clients=client_count,
            threads=self.THREADS,
            duration=self.DURATION,
            workload="select-only"
        )
        
        # Salva métricas
        performance_writer_baseline.write(metrics)
        
        # Exibe resultados
        self._print_performance_metrics(metrics)
        
        # Valida que teste executou
        assert metrics.total_transactions > 0, "Nenhuma transação executada"
        assert metrics.tps_total > 0, "TPS zerado"
        
        print(f"\n✅ Baseline concluído ({client_count} clientes)")
        print(f"   TPS: {metrics.tps_total:.2f}")
        print(f"   Latência: {metrics.latency_avg:.2f}ms")
    
    @pytest.mark.parametrize("client_count", [10, 20, 40, 80, 120, 160, 200])
    def test_baseline_mixed_workload(
        self,
        client_count,
        performance_collector,
        performance_writer_baseline
    ):
        """
        Teste baseline com carga mista (leitura + escrita) - Escalabilidade
        
        Parâmetros pgbench:
        - Clientes: parametrizado (10, 20, 40, 80, 120, 160, 200)
        - Threads: 8
        - Duração: 60s
        - Workload: mixed
        """
        print("\n" + "="*70)
        print(f"TESTE DE PERFORMANCE - BASELINE (MIXED) - {client_count} CLIENTES")
        print("="*70)
        
        print("\n[1/1] Executando teste de carga mista...")
        print(f"  Clientes: {client_count}, Threads: {self.THREADS}, Duração: {self.DURATION}s")
        
        metrics = performance_collector.run_pgbench(
            test_case=f"baseline_mixed_{client_count}clients",
            scenario=self.SCENARIO,
            container_name=self.CONTAINER_NAME,
            host=self.HOST,
            port=self.PORT,
            user=self.USER,
            password=self.PASSWORD,
            database=self.DATABASE,
            clients=client_count,
            threads=self.THREADS,
            duration=self.DURATION,
            workload="mixed"
        )

        performance_writer_baseline.write(metrics)
        self._print_performance_metrics(metrics)
        
        assert metrics.total_transactions > 0
        print(f"\n✅ Baseline (mixed) concluído ({client_count} clientes)")
    
    def _print_performance_metrics(self, metrics):
        """Exibe métricas formatadas"""
        print("\n" + "="*70)
        print("MÉTRICAS DE PERFORMANCE")
        print("="*70)
        
        # Informações do pgbench
        if metrics.pgbench_version:
            print(f"pgbench versão:        {metrics.pgbench_version}")
        if metrics.transaction_type:
            print(f"Transaction type:      {metrics.transaction_type}")
        if metrics.scaling_factor:
            print(f"Scaling factor:        {metrics.scaling_factor}")
        if metrics.query_mode:
            print(f"Query mode:            {metrics.query_mode}")
        if metrics.max_tries:
            print(f"Max tries:             {metrics.max_tries}")
        
        print("-"*70)
        print(f"Cenário:               {metrics.scenario}")
        print(f"Workload:              {metrics.workload_type}")
        print(f"Clientes:              {metrics.clients}")
        print(f"Threads:               {metrics.threads}")
        print(f"Duração:               {metrics.duration_seconds}s")
        
        print("-"*70)
        print("THROUGHPUT (TPS)")
        print(f"  TPS (total):         {metrics.tps_total or 0:.2f}")
        if metrics.tps_including_connections:
            print(f"  TPS (incl. conn):    {metrics.tps_including_connections:.2f}")
        if metrics.tps_excluding_connections:
            print(f"  TPS (excl. conn):    {metrics.tps_excluding_connections:.2f}")
        
        print("-"*70)
        print("LATÊNCIA (ms)")
        print(f"  Média:               {metrics.latency_avg or 0:.3f} ms")
        if metrics.latency_stddev:
            print(f"  Desvio padrão:       {metrics.latency_stddev:.3f} ms")
        if metrics.latency_min:
            print(f"  Mínima:              {metrics.latency_min:.3f} ms")
        if metrics.latency_max:
            print(f"  Máxima:              {metrics.latency_max:.3f} ms")
        
        print("-"*70)
        print("TRANSAÇÕES")
        print(f"  Total processadas:   {metrics.total_transactions or 0:,}")
        print(f"  Falhadas:            {metrics.failed_transactions or 0:,}", end="")
        if metrics.failed_transactions_percent is not None:
            print(f" ({metrics.failed_transactions_percent:.3f}%)")
        else:
            print()
        print(f"  Taxa de sucesso:     {metrics.success_rate or 0:.2f}%")
        
        if metrics.initial_connection_time:
            print("-"*70)
            print(f"Tempo conexão inicial: {metrics.initial_connection_time:.2f} ms")
        
        print("="*70)

        
    def _initialize_database_once(self, performance_collector):
        """
        Inicializa o database pgbench apenas UMA vez para toda a classe de testes.
        Com 32GB, isso evita reinicializar o database a cada teste parametrizado.
        Utiliza os parâmetros centralizados em BaselineConfig.
        """
        print("\n" + "="*70)
        print("🔧 INICIALIZANDO DATABASE PGBENCH (32GB) - APENAS UMA VEZ")
        print("="*70)
        print(f"  Scale factor: {BaselineConfig.SCALE} (~32GB)")
        print("  Isso pode levar alguns minutos...")
        
        success = performance_collector.initialize_pgbench_database(
            container_name=BaselineConfig.CONTAINER_NAME,
            host=BaselineConfig.HOST,
            port=BaselineConfig.PORT,
            user=BaselineConfig.USER,
            password=BaselineConfig.PASSWORD,
            database=BaselineConfig.DATABASE,
            scale=BaselineConfig.SCALE
        )
        
        assert success, "❌ Falha ao inicializar database"
        print("✅ Database inicializado com sucesso!")
        print("="*70)
        
        return True
