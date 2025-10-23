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
    THREADS = 4
    DURATION = 180
    SCALE = 2000  # (DEVE SER MAIOR QUE A QT DE RAM DO SISTEMA! SCALE 1 =~ 16MB)

@pytest.mark.baseline
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
    
    @pytest.mark.baseline_select_only
    @pytest.mark.parametrize("client_count", [10, 25, 50, 75, 100])
    def test_baseline_select_only(
        self,
        client_count,
        performance_collector,
        performance_writer_baseline,
        docker_stats_collector,
        docker_stats_writer
    ):
        """
        Teste de Performance (Baseline) - Escalabilidade
        
        Cenário 1: PostgreSQL standalone
        Carga: SELECT-only (leitura)
        
        Parâmetros pgbench:
        - Clientes: parametrizado (10, 25, 50, 75, 100)
        - Threads: 8
        - Duração: 60s
        - Workload: select-only
        """
        print("\n" + "="*70)
        print(f"TESTE DE PERFORMANCE - BASELINE (SELECT-ONLY) - {client_count} CLIENTES")
        print("="*70)

        print("\n[1/1] Inicializando database pgbench (32GB)...")
        inicialized = self._initialize_database_once(performance_collector)

        # Inicia coleta de Docker Stats
        containers_to_monitor = ["postgres-baseline", "pgbench-client"]
        stats_collector = docker_stats_collector(containers_to_monitor, interval=2.0)
        stats_collector.start()

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
        
        # Para coleta de Docker Stats
        stats_collector.stop()
        docker_metrics = stats_collector.get_metrics(f"baseline_select_only_{client_count}clients")
        
        # Salva métricas
        performance_writer_baseline.write(metrics)
        docker_stats_writer.write(docker_metrics.to_dict())
        
        # Exibe resultados
        self._print_performance_metrics(metrics)
        self._print_docker_stats(docker_metrics)
        
        # Valida que teste executou
        assert metrics.total_transactions > 0, "Nenhuma transação executada"
        assert metrics.tps_total > 0, "TPS zerado"
        
        print(f"\n✅ Baseline concluído ({client_count} clientes)")
        print(f"   TPS: {metrics.tps_total:.2f}")
        print(f"   Latência: {metrics.latency_avg:.2f}ms")
    
    @pytest.mark.baseline_select_only_reconnect
    @pytest.mark.parametrize("client_count", [10, 25, 50, 75, 100])
    def test_baseline_select_only_with_reconnect(
        self,
        client_count,
        performance_collector,
        performance_writer_baseline,
        docker_stats_collector,
        docker_stats_writer
    ):
        """
        Teste de Performance (Baseline) - Escalabilidade com Reconexão
        
        Cenário 1: PostgreSQL standalone
        Carga: SELECT-only (leitura) com reconexão por transação
        
        Parâmetros pgbench:
        - Clientes: parametrizado (10, 25, 50, 75, 100)
        - Threads: 8
        - Duração: 60s
        - Workload: select-only
        - Reconnect: True (flag -C)
        """
        print("\n" + "="*70)
        print(f"TESTE DE PERFORMANCE - BASELINE (SELECT-ONLY + RECONNECT) - {client_count} CLIENTES")
        print("="*70)

        print("\n[1/1] Inicializando database pgbench (32GB)...")
        inicialized = self._initialize_database_once(performance_collector)

        # Inicia coleta de Docker Stats
        containers_to_monitor = ["postgres-baseline", "pgbench-client"]
        stats_collector = docker_stats_collector(containers_to_monitor, interval=2.0)
        stats_collector.start()

        # Executa teste de carga (database já foi inicializado pela fixture)
        print("\n[2/2] Executando teste de carga com reconexão...")
        print(f"  Clientes: {client_count}, Threads: {self.THREADS}, Duração: {self.DURATION}s")
        print(f"  Database: 32GB (scale={self.SCALE})")
        print(f"  Workload: SELECT-only (leitura)")
        print(f"  Reconnect: True (flag -C)")
        
        metrics = performance_collector.run_pgbench(
            test_case=f"baseline_select_only_reconnect_{client_count}clients",
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
            workload="select-only",
            reconnect=True
        )
        
        # Para coleta de Docker Stats
        stats_collector.stop()
        docker_metrics = stats_collector.get_metrics(f"baseline_select_only_reconnect_{client_count}clients")
        
        # Salva métricas
        performance_writer_baseline.write(metrics)
        docker_stats_writer.write(docker_metrics.to_dict())
        
        # Exibe resultados
        self._print_performance_metrics(metrics)
        self._print_docker_stats(docker_metrics)
        
        # Valida que teste executou
        assert metrics.total_transactions > 0, "Nenhuma transação executada"
        assert metrics.tps_total > 0, "TPS zerado"
        
        print(f"\n✅ Baseline com reconexão concluído ({client_count} clientes)")
        print(f"   TPS: {metrics.tps_total:.2f}")
        print(f"   Latência: {metrics.latency_avg:.2f}ms")
    
    @pytest.mark.baseline_mixed_workload
    @pytest.mark.parametrize("client_count", [10, 25, 50, 75, 100])
    def test_baseline_mixed_workload(
        self,
        client_count,
        performance_collector,
        performance_writer_baseline,
        docker_stats_collector,
        docker_stats_writer
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
        
        # Inicia coleta de Docker Stats
        containers_to_monitor = ["postgres-baseline", "pgbench-client"]
        stats_collector = docker_stats_collector(containers_to_monitor, interval=2.0)
        stats_collector.start()

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
        
        # Para coleta de Docker Stats
        stats_collector.stop()
        docker_metrics = stats_collector.get_metrics(f"baseline_select_only_{client_count}clients")

        performance_writer_baseline.write(metrics)
        docker_stats_writer.write(docker_metrics.to_dict())
        
        self._print_performance_metrics(metrics)
        self._print_docker_stats(docker_metrics)
        
        
        assert metrics.total_transactions > 0
        print(f"\n✅ Baseline (mixed) concluído ({client_count} clientes)")
    
    @pytest.mark.baseline_mixed_workload_reconnect
    @pytest.mark.parametrize("client_count", [10, 25, 50, 75, 100])
    def test_baseline_mixed_workload_with_reconnect(
        self,
        client_count,
        performance_collector,
        performance_writer_baseline,
        docker_stats_collector,
        docker_stats_writer
    ):
        """
        Teste baseline com carga mista (leitura + escrita) e reconexão - Escalabilidade
        
        Parâmetros pgbench:
        - Clientes: parametrizado (10, 25, 50, 75, 100)
        - Threads: 4
        - Duração: 60s
        - Workload: mixed
        - Reconnect: True (flag -C)
        """
        print("\n" + "="*70)
        print(f"TESTE DE PERFORMANCE - BASELINE (MIXED + RECONNECT) - {client_count} CLIENTES")
        print("="*70)
        
        print("\n[1/1] Executando teste de carga mista com reconexão...")
        print(f"  Clientes: {client_count}, Threads: {self.THREADS}, Duração: {self.DURATION}s")
        print(f"  Reconnect: True (flag -C)")
        
        # Inicia coleta de Docker Stats
        containers_to_monitor = ["postgres-baseline", "pgbench-client"]
        stats_collector = docker_stats_collector(containers_to_monitor, interval=2.0)
        stats_collector.start()

        metrics = performance_collector.run_pgbench(
            test_case=f"baseline_mixed_reconnect_{client_count}clients",
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
            workload="mixed",
            reconnect=True
        )
        
        # Para coleta de Docker Stats
        stats_collector.stop()
        docker_metrics = stats_collector.get_metrics(f"baseline_mixed_reconnect_{client_count}clients")

        performance_writer_baseline.write(metrics)
        docker_stats_writer.write(docker_metrics.to_dict())
        
        self._print_performance_metrics(metrics)
        self._print_docker_stats(docker_metrics)
        
        
        assert metrics.total_transactions > 0
        print(f"\n✅ Baseline (mixed) com reconexão concluído ({client_count} clientes)")
    
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
    
    def _print_docker_stats(self, metrics):
        """Exibe estatísticas do Docker formatadas"""
        print("\n" + "="*70)
        print("ESTATÍSTICAS DOCKER")
        print("="*70)
        print(f"Duração da coleta: {metrics.duration_seconds:.2f}s")
        print(f"Containers monitorados: {len(metrics.containers)}")
        
        for container_name, stats in metrics.containers.items():
            print("\n" + "-"*70)
            print(f"Container: {container_name}")
            print("-"*70)
            print(f"  CPU:")
            print(f"    Média:  {stats.cpu_percent_avg:.2f}%")
            print(f"    Máxima: {stats.cpu_percent_max:.2f}%")
            print(f"  Memória:")
            print(f"    Média:  {stats.memory_usage_bytes_avg / (1024**2):.2f} MB ({stats.memory_percent_avg:.2f}%)")
            print(f"    Máxima: {stats.memory_usage_bytes_max / (1024**2):.2f} MB ({stats.memory_percent_max:.2f}%)")
            print(f"  Rede:")
            print(f"    RX: {stats.network_rx_bytes_total / (1024**2):.2f} MB")
            print(f"    TX: {stats.network_tx_bytes_total / (1024**2):.2f} MB")
            print(f"  Disco:")
            print(f"    Read:  {stats.block_read_bytes_total / (1024**2):.2f} MB")
            print(f"    Write: {stats.block_write_bytes_total / (1024**2):.2f} MB")
            print(f"  Amostras coletadas: {stats.sample_count}")
        
        print("="*70)
