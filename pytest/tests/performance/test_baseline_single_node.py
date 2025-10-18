"""
Teste de Performance - Baseline (Single Node)

Testa performance contra PostgreSQL standalone (sem HA)
"""
import pytest


@pytest.mark.performance
@pytest.mark.baseline
class TestPerformanceBaseline:
    
    def test_baseline_select_only(
        self,
        performance_collector,
        performance_writer
    ):
        """
        3.4.2 - Teste de Performance (Baseline)
        
        Cenário 1: PostgreSQL standalone
        Carga: SELECT-only (leitura)
        
        Parâmetros pgbench:
        - Clientes: 10
        - Threads: 4
        - Duração: 60s
        - Workload: select-only
        """
        print("\n" + "="*60)
        print("TESTE DE PERFORMANCE - BASELINE (SELECT-ONLY)")
        print("="*60)
        
        # Inicializa database pgbench
        print("\n[1/2] Inicializando database pgbench...")
        success = performance_collector.initialize_pgbench_database(
            host="localhost",
            port=5432,
            scale=10  # ~160MB
        )
        assert success, "Falha ao inicializar database"
        print("✓ Database inicializado (scale=10)")
        
        # Executa teste de carga
        print("\n[2/2] Executando teste de carga...")
        print("  Clientes: 10, Threads: 4, Duração: 60s")
        print("  Workload: SELECT-only (leitura)")
        
        metrics = performance_collector.run_pgbench(
            test_case="baseline_select_only",
            scenario="baseline",
            host="localhost",
            port=5432,
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
        assert metrics.total_transactions > 0, "Nenhuma transação executada"
        assert metrics.tps_total > 0, "TPS zerado"
        
        print(f"\n✅ Baseline concluído")
        print(f"   TPS: {metrics.tps_total:.2f}")
        print(f"   Latência: {metrics.latency_avg:.2f}ms")
    
    def test_baseline_mixed_workload(
        self,
        performance_collector,
        performance_writer
    ):
        """
        Teste baseline com carga mista (leitura + escrita)
        """
        print("\n" + "="*60)
        print("TESTE DE PERFORMANCE - BASELINE (MIXED)")
        print("="*60)
        
        print("\n[1/1] Executando teste de carga mista...")
        
        metrics = performance_collector.run_pgbench(
            test_case="baseline_mixed",
            scenario="baseline",
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
        print(f"\n✅ Baseline (mixed) concluído")
    
    def _print_performance_metrics(self, metrics):
        """Exibe métricas formatadas"""
        print("\n" + "="*60)
        print("MÉTRICAS DE PERFORMANCE")
        print("="*60)
        print(f"Cenário:               {metrics.scenario}")
        print(f"Workload:              {metrics.workload_type}")
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
