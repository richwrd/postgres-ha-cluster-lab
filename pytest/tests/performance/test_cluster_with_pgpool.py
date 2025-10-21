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
    THREADS = 8
    DURATION = 60
    SCALE = 10 # 2200  # ~32GB (DEVE SER O DOBRO DA QT DE RAM DO SISTEMA)

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
        
        # Salva métricas
        performance_writer_cluster.write(metrics)
        
        # Exibe resultados
        self._print_performance_metrics(metrics)
        
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

        performance_writer_cluster.write(metrics)
        self._print_performance_metrics(metrics)
        
        assert metrics.total_transactions > 0
        print(f"\n✅ Cluster (mixed) concluído ({client_count} clientes)")

    @pytest.mark.cluster_select_only_reconnect
    @pytest.mark.parametrize("client_count", [10, 25, 50, 75, 100])
    def test_cluster_select_only_reconnect(
        self,
        client_count,
        performance_collector,
        performance_writer_cluster,
        get_primary_node
    ):
        """
        Teste de Performance (Cluster) - Leitura com Reconexão
        
        Cenário 2: Cluster PostgreSQL + PgPool
        Carga: SELECT-only (leitura) com flag -C (reconectar a cada transação)
        
        Este teste avalia o impacto de re-estabelecer conexões a cada transação,
        simulando aplicações que não mantêm pool de conexões ou que possuem
        conexões de vida curta.
        
        Parâmetros pgbench:
        - Clientes: parametrizado (10, 25, 50, 75, 100)
        - Threads: 8
        - Duração: 60s
        - Workload: select-only
        - Flag: -C (reconnect)
        """
        print("\n" + "="*70)
        print(f"TESTE DE PERFORMANCE - CLUSTER (SELECT-ONLY + RECONNECT) - {client_count} CLIENTES")
        print("="*70)
        
        # Garante que o database foi inicializado (só executa na primeira vez)
        self._ensure_database_initialized(performance_collector, get_primary_node)

        # Executa teste de carga com reconexão
        print("\nExecutando teste de carga com reconexão...")
        print(f"  Clientes: {client_count}, Threads: {self.THREADS}, Duração: {self.DURATION}s")
        print(f"  Database: ~{self.SCALE * 16}MB (scale={self.SCALE})")
        print(f"  Workload: SELECT-only (leitura)")
        print(f"  Conexão: {self.HOST}:{self.PORT} (PgPool)")
        print(f"  ⚠️  Flag -C ativa: Nova conexão a cada transação")
        
        metrics = performance_collector.run_pgbench(
            test_case=f"cluster_select_only_reconnect_{client_count}clients",
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
            reconnect=True  # Flag -C
        )
        
        # Salva métricas
        performance_writer_cluster.write(metrics)
        
        # Exibe resultados
        self._print_performance_metrics(metrics)
        
        # Valida que teste executou
        assert metrics.total_transactions > 0, "Nenhuma transação executada"
        assert metrics.tps_total > 0, "TPS zerado"
        
        print(f"\n✅ Cluster (reconnect) concluído ({client_count} clientes)")
        print(f"   TPS: {metrics.tps_total:.2f}")
        print(f"   Latência: {metrics.latency_avg:.2f}ms")
        print(f"   ⚠️  Overhead de reconexão esperado")
    
    @pytest.mark.cluster_mixed_workload_reconnect
    @pytest.mark.parametrize("client_count", [10, 25, 50, 75, 100])
    def test_cluster_mixed_workload_reconnect(
        self,
        client_count,
        performance_collector,
        performance_writer_cluster,
        get_primary_node
    ):
        """
        Teste de Performance (Cluster) - Workload Misto com Reconexão
        
        Cenário 2: Cluster PostgreSQL + PgPool
        Carga: Mixed (leitura + escrita) com flag -C (reconectar a cada transação)
        
        Este teste avalia o impacto de re-estabelecer conexões a cada transação
        em um workload misto que inclui tanto leituras quanto escritas.
        Simula aplicações que não mantêm pool de conexões e realizam operações
        variadas no banco de dados.
        
        Parâmetros pgbench:
        - Clientes: parametrizado (10, 25, 50, 75, 100)
        - Threads: 8
        - Duração: 60s
        - Workload: mixed (SELECT, UPDATE, INSERT)
        - Flag: -C (reconnect)
        """
        print("\n" + "="*70)
        print(f"TESTE DE PERFORMANCE - CLUSTER (MIXED + RECONNECT) - {client_count} CLIENTES")
        print("="*70)
        
        # Garante que o database foi inicializado (só executa na primeira vez)
        self._ensure_database_initialized(performance_collector, get_primary_node)

        # Executa teste de carga mista com reconexão
        print("\nExecutando teste de carga mista com reconexão...")
        print(f"  Clientes: {client_count}, Threads: {self.THREADS}, Duração: {self.DURATION}s")
        print(f"  Database: ~{self.SCALE * 16}MB (scale={self.SCALE})")
        print(f"  Workload: Mixed (leitura + escrita)")
        print(f"  Conexão: {self.HOST}:{self.PORT} (PgPool)")
        print(f"  ⚠️  Flag -C ativa: Nova conexão a cada transação")
        
        metrics = performance_collector.run_pgbench(
            test_case=f"cluster_mixed_reconnect_{client_count}clients",
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
            reconnect=True  # Flag -C
        )
        
        # Salva métricas
        performance_writer_cluster.write(metrics)
        
        # Exibe resultados
        self._print_performance_metrics(metrics)
        
        # Valida que teste executou
        assert metrics.total_transactions > 0, "Nenhuma transação executada"
        assert metrics.tps_total > 0, "TPS zerado"
        
        print(f"\n✅ Cluster (mixed + reconnect) concluído ({client_count} clientes)")
        print(f"   TPS: {metrics.tps_total:.2f}")
        print(f"   Latência: {metrics.latency_avg:.2f}ms")
        print(f"   ⚠️  Overhead de reconexão + escritas esperado")
    
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
