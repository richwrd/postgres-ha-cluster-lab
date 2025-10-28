"""
Teste de Performance - Cluster com PgPool
"""
import pytest

# Configurações centralizadas
class ClusterConfig:
    """Configurações compartilhadas entre fixture e testes"""
    
    # Conexão
    CONTAINER_NAME = "pgbench-client"
    HOST = "pgpool"
    PORT = 5432
    USER = "teste"
    PASSWORD = "zxwJA9P6C0hie03dwfNNP"
    DATABASE = "postgres"
    SCENARIO = "cluster_with_pgpool"
    
    # Carga
    THREADS = 4
    DURATION = 180
    SCALE = 2000  # (DEVE SER MAIOR QUE A QT DE RAM DO SISTEMA! SCALE 1 =~ 16MB)

@pytest.mark.cluster_performance
class TestPerformanceCluster:
    
    # Herda configurações da classe centralizada
    CONTAINER_NAME = ClusterConfig.CONTAINER_NAME
    HOST = ClusterConfig.HOST
    PORT = ClusterConfig.PORT
    USER = ClusterConfig.USER
    PASSWORD = ClusterConfig.PASSWORD
    DATABASE = ClusterConfig.DATABASE
    SCENARIO = ClusterConfig.SCENARIO
    THREADS = ClusterConfig.THREADS
    DURATION = ClusterConfig.DURATION
    SCALE = ClusterConfig.SCALE
    
    # Containers para monitoramento Docker Stats
    CONTAINERS_TO_MONITOR = [
        "etcd-1",
        "etcd-2",
        "etcd-3",
        "patroni-postgres-1",
        "patroni-postgres-2",
        "patroni-postgres-3",
        "pgpool",
        "pgbench-client"
    ]
    
    # Flag para controlar se já inicializou o database
    _db_initialized = False
    
    def _ensure_database_initialized(self, performance_collector, get_primary_node):
        """
        Garante que o database foi inicializado apenas uma vez.
        Chamado no início de cada teste, mas só executa na primeira vez.
        """
        if TestPerformanceCluster._db_initialized:
            print("\n✅ Database já inicializado (pulando setup)")
            return True
        
        print("\n" + "="*70)
        print("🔧 INICIALIZANDO DATABASE PGBENCH (PRIMEIRA VEZ)")
        print("="*70)
        
        primary_node = get_primary_node()
        
        if not primary_node:
            error_msg = "❌ Não foi possível identificar o nó primário do cluster!"
            print(error_msg)
            pytest.fail(error_msg)
        
        print(f"  Nó Primário: {primary_node}")
        print(f"  Scale factor: {ClusterConfig.SCALE} (~{ClusterConfig.SCALE * 16}MB)")
        print(f"  Conexão: {primary_node}:{ClusterConfig.PORT}")
        print(f"  Database: {ClusterConfig.DATABASE}")
        print(f"  Isso pode levar alguns minutos...")
        
        success = performance_collector.initialize_pgbench_database(
            container_name=ClusterConfig.CONTAINER_NAME,
            host=primary_node,
            port=ClusterConfig.PORT,
            user=ClusterConfig.USER,
            password=ClusterConfig.PASSWORD,
            database=ClusterConfig.DATABASE,
            scale=ClusterConfig.SCALE
        )
        
        if not success:
            error_msg = "❌ ERRO CRÍTICO: Falha ao inicializar database pgbench!"
            print(error_msg)
            pytest.fail(error_msg)
        
        TestPerformanceCluster._db_initialized = True
        print("\n✅ Database inicializado com sucesso!")
        print("="*70)
        return True
    
    @pytest.mark.cluster_select_only
    @pytest.mark.parametrize("client_count", [10, 25, 50, 75, 100])
    def test_cluster_select_only(
        self,
        client_count,
        performance_collector,
        performance_writer_cluster,
        docker_stats_collector,
        docker_stats_writer,
        get_primary_node
    ):
        """
        Teste de Performance (Cluster) - Escalabilidade
        
        Cenário 2: Cluster PostgreSQL + PgPool
        Carga: SELECT-only (leitura)
        
        Parâmetros pgbench:
        - Clientes: parametrizado (10, 25, 50, 75, 100)
        - Threads: 8
        - Duração: 60s
        - Workload: select-only
        """
        print("\n" + "="*70)
        print(f"TESTE DE PERFORMANCE - CLUSTER (SELECT-ONLY) - {client_count} CLIENTES")
        print("="*70)
        
        # Garante que o database foi inicializado (só executa na primeira vez)
        self._ensure_database_initialized(performance_collector, get_primary_node)

        # Inicia coleta de Docker Stats
        stats_collector = docker_stats_collector(self.CONTAINERS_TO_MONITOR, interval=2.0)
        stats_collector.start()

        # Executa teste de carga
        print("\nExecutando teste de carga...")
        print(f"  Clientes: {client_count}, Threads: {self.THREADS}, Duração: {self.DURATION}s")
        print(f"  Database: ~{self.SCALE * 16}MB (scale={self.SCALE})")
        print(f"  Workload: SELECT-only (leitura)")
        print(f"  Conexão: {self.HOST}:{self.PORT} (PgPool)")
        
        metrics = performance_collector.run_pgbench(
            test_case=f"cluster_select_only_{client_count}clients",
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
        docker_metrics = stats_collector.get_metrics(f"cluster_select_only_{client_count}clients")
        
        # Salva métricas
        performance_writer_cluster.write(metrics)
        docker_stats_writer.write(docker_metrics.to_dict())
        
        # Exibe resultados
        self._print_performance_metrics(metrics)
        self._print_docker_stats(docker_metrics)
        
        # Valida que teste executou
        assert metrics.total_transactions > 0, "Nenhuma transação executada"
        assert metrics.tps_total > 0, "TPS zerado"
        
        print(f"\n✅ Cluster concluído ({client_count} clientes)")
        print(f"   TPS: {metrics.tps_total:.2f}")
        print(f"   Latência: {metrics.latency_avg:.2f}ms")
    
    @pytest.mark.cluster_mixed_workload
    @pytest.mark.parametrize("client_count", [10, 25, 50, 75, 100])
    def test_cluster_mixed_workload(
        self,
        client_count,
        performance_collector,
        performance_writer_cluster,
        docker_stats_collector,
        docker_stats_writer,
        get_primary_node
    ):
        """
        Teste cluster com carga mista (leitura + escrita) - Escalabilidade
        
        Parâmetros pgbench:
        - Clientes: parametrizado (10, 25, 50, 75, 100)
        - Threads: 8
        - Duração: 60s
        - Workload: mixed
        """
        print("\n" + "="*70)
        print(f"TESTE DE PERFORMANCE - CLUSTER (MIXED) - {client_count} CLIENTES")
        print("="*70)
        
        # Garante que o database foi inicializado (só executa na primeira vez)
        self._ensure_database_initialized(performance_collector, get_primary_node)
        
        # Inicia coleta de Docker Stats
        stats_collector = docker_stats_collector(self.CONTAINERS_TO_MONITOR, interval=2.0)
        stats_collector.start()
        
        print("\nExecutando teste de carga mista...")
        print(f"  Clientes: {client_count}, Threads: {self.THREADS}, Duração: {self.DURATION}s")
        print(f"  Conexão: {self.HOST}:{self.PORT} (PgPool)")
        
        metrics = performance_collector.run_pgbench(
            test_case=f"cluster_mixed_{client_count}clients",
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
        docker_metrics = stats_collector.get_metrics(f"cluster_mixed_{client_count}clients")

        performance_writer_cluster.write(metrics)
        docker_stats_writer.write(docker_metrics.to_dict())
        
        self._print_performance_metrics(metrics)
        self._print_docker_stats(docker_metrics)
        
        assert metrics.total_transactions > 0
        print(f"\n✅ Cluster (mixed) concluído ({client_count} clientes)")


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
            # Detecta se é tempo médio de conexão (flag -C) ou inicial
            if metrics.tps_including_connections and not metrics.tps_excluding_connections:
                print(f"Tempo médio conexão:   {metrics.initial_connection_time:.2f} ms (flag -C ativa)")
            else:
                print(f"Tempo conexão inicial: {metrics.initial_connection_time:.2f} ms")
        
        print("="*70)
    
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
