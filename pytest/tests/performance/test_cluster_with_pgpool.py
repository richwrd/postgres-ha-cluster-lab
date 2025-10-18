"""
Teste de Performance - Cluster com PgPool

Testa performance contra cluster HA com PgPool-II
"""
import pytest


@pytest.mark.performance
@pytest.mark.cluster
class TestPerformanceCluster:
    
    def test_cluster_select_only_with_pgpool(
        self,
        performance_collector,
        performance_writer,
        cluster_healthy
    ):
        """
        3.4.2 - Teste de Performance (Cluster HA)
        
        Cenário 2: Cluster HA com PgPool-II
        Carga: SELECT-only (leitura com load balancing)
        
        Parâmetros pgbench:
        - Clientes: 10
        - Threads: 4
        - Duração: 60s
        - Workload: select-only
        - Via PgPool (porta 5432)
        """
        print("\n" + "="*60)
        print("TESTE DE PERFORMANCE - CLUSTER + PGPOOL (SELECT-ONLY)")
        print("="*60)
        
        # Inicializa database pgbench via PgPool
        print("\n[1/2] Inicializando database pgbench via PgPool...")
        success = performance_collector.initialize_pgbench_database(
            host="localhost",
            port=5432,  # Porta do PgPool
            scale=10
        )
        assert success, "Falha ao inicializar database"
        print("✓ Database inicializado via PgPool")
        
        # Executa teste de carga
        print("\n[2/2] Executando teste de carga...")
        print("  Clientes: 10, Threads: 4, Duração: 60s")
        print("  Workload: SELECT-only (com load balancing)")
        
        metrics = performance_collector.run_pgbench(
            test_case="cluster_select_only_pgpool",
            scenario="cluster",
            host="localhost",
            port=5432,  # PgPool
            clients=10,
            threads=4,
            duration=60,
            workload="select-only"
        )
        
        # Salva métricas
        performance_writer.write(metrics)
        
        # Exibe resultados
        self._print_performance_metrics(metrics)
        
        # Valida que teste executou
        assert metrics.total_transactions > 0
        assert metrics.tps_total > 0
        
        print(f"\n✅ Cluster concluído")
        print(f"   TPS: {metrics.tps_total:.2f}")
        print(f"   Latência: {metrics.latency_avg:.2f}ms")
    
    def test_cluster_mixed_workload_with_pgpool(
        self,
        performance_collector,
        performance_writer,
        cluster_healthy
    ):
        """
        Teste cluster com carga mista via PgPool
        """
        print("\n" + "="*60)
        print("TESTE DE PERFORMANCE - CLUSTER + PGPOOL (MIXED)")
        print("="*60)
        
        print("\n[1/1] Executando teste de carga mista...")
        
        metrics = performance_collector.run_pgbench(
            test_case="cluster_mixed_pgpool",
            scenario="cluster",
            host="localhost",
            port=5432,
            clients=10,
            threads=4,
            duration=60,
            workload="mixed"
        )
        
        performance_writer.write(metrics)
        self._print_performance_metrics(metrics)
        
        assert metrics.total_transactions > 0
        print(f"\n✅ Cluster (mixed) concluído")
    
    def _print_performance_metrics(self, metrics):
        """Exibe métricas formatadas"""
        print("\n" + "="*60)
        print("MÉTRICAS DE PERFORMANCE - CLUSTER")
        print("="*60)
        print(f"Cenário:               {metrics.scenario}")
        print(f"Workload:              {metrics.workload_type}")
        print(f"PgPool habilitado:     {'SIM' if metrics.pgpool_enabled else 'NÃO'}")
        print(f"Clientes:              {metrics.clients}")
        print(f"Threads:               {metrics.threads}")
        print(f"Duração:               {metrics.duration_seconds}s")
        print("-"*60)
        print(f"TPS (total):           {metrics.tps_total:.2f}")
        print(f"TPS (excl. conn):      {metrics.tps_excluding_connections:.2f}")
        print(f"Latência média:        {metrics.latency_avg:.2f}ms")
        print(f"Total transações:      {metrics.total_transactions}")
        print(f"Transações falhadas:   {metrics.failed_transactions}")
        print(f"Taxa de sucesso:       {metrics.success_rate:.2f}%")
        print("="*60)
