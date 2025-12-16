# Guia de Testes

Documentação completa sobre como executar os testes de resiliência e performance do cluster.

## Configurar Ambiente de Testes

```bash
cd pytest

# Criar ambiente virtual
python3 -m venv .venv
source .venv/bin/activate  # No Windows: .venv\Scripts\activate

# Instalar dependências
pip install -r requirements.txt
```

## Testes de Resiliência

### RTO (Recovery Time Objective) - Falha do Nó Primário

Mede o tempo que o cluster leva para recuperar de uma falha completa do nó primário.

```bash
# Via script helper
./scripts/test/run-crash-up.sh

# Ou diretamente com pytest
pytest pytest/tests/resilience/test_rto_primary_failure.py::TestRTOPrimaryFailure::test_primary_node_complete_failure -v -s
```

### RTO - Switchover Planejado

Mede o tempo de recuperação durante uma troca planejada de líder.

```bash
pytest pytest/tests/resilience/test_rto_planned_switchover.py -v -s
```

### RPO (Recovery Point Objective)

Avalia a perda de dados durante uma falha do primário.

```bash
pytest pytest/tests/resilience/test_rpo_primary_failure.py -v -s
```

**Resultados:** Os resultados são salvos em `pytest/outputs/resilience/` no formato JSONL.

## Testes de Performance

### Baseline (Nó Único)

Testes de performance em um único nó PostgreSQL sem cluster.

**SELECT-only workload:**

```bash
pytest pytest/tests/performance/test_baseline_single_node.py::TestPerformanceBaseline::test_baseline_select_only -v -s
```

**Simple-update workload:**

```bash
pytest pytest/tests/performance/test_baseline_single_node.py::TestPerformanceBaseline::test_baseline_simple_update -v -s
```

**TPC-B-like workload:**

```bash
pytest pytest/tests/performance/test_baseline_single_node.py::TestPerformanceBaseline::test_baseline_tpcb_like -v -s
```

### Cluster com PgPool

Testes de performance no cluster com balanceamento de carga pelo PgPool.

**SELECT-only com balanceamento:**

```bash
pytest pytest/tests/performance/test_cluster_with_pgpool.py::TestPerformanceCluster::test_cluster_select_only -v -s
```

**Simple-update workload:**

```bash
pytest pytest/tests/performance/test_cluster_with_pgpool.py::TestPerformanceCluster::test_cluster_simple_update -v -s
```

**TPC-B-like workload:**

```bash
pytest pytest/tests/performance/test_cluster_with_pgpool.py::TestPerformanceCluster::test_cluster_tpcb_like -v -s
```

**Resultados:** Os resultados são salvos em `pytest/outputs/performance/` no formato JSONL.

## Scripts de Automação de Testes

### Testes com Cache Frio (requer sudo)

Para resultados mais consistentes, os scripts podem limpar o cache do sistema entre execuções.

**Baseline com múltiplas execuções:**

```bash
sudo ./scripts/test/run-benchmark-baseline.sh
```

**Cluster com múltiplas execuções:**

```bash
sudo ./scripts/test/run-benchmark-cluster.sh
```

## Estrutura de Outputs

```
pytest/outputs/
├── resilience/
│   ├── rto_primary_failure_YYYYMMDD_HHMMSS.jsonl
│   ├── rto_planned_switchover_YYYYMMDD_HHMMSS.jsonl
│   └── rpo_primary_failure_YYYYMMDD_HHMMSS.jsonl
│
└── performance/
    ├── baseline_select_only_YYYYMMDD_HHMMSS.jsonl
    ├── baseline_simple_update_YYYYMMDD_HHMMSS.jsonl
    ├── cluster_select_only_YYYYMMDD_HHMMSS.jsonl
    └── cluster_simple_update_YYYYMMDD_HHMMSS.jsonl
```

## Métricas Coletadas

### Resiliência (RTO/RPO)

- **RTO**: Tempo total de recuperação (em segundos)
- **RPO**: Número de transações perdidas
- Timestamps de cada fase do processo
- Status de saúde do cluster durante a recuperação

### Performance

- **TPS** (Transactions Per Second): Taxa de transações por segundo
- **Latência média**: Tempo médio de resposta (ms)
- **Latência p95/p99**: Percentis de latência
- Estatísticas do pgbench
- Métricas de recursos (CPU, memória, I/O) via Docker Stats

## Análise de Resultados

_Em breve será disponibilizado um guia completo de análise e visualização dos resultados dos testes._

## Troubleshooting

### Testes falhando

1. Verifique se o cluster está funcionando: `./scripts/health_checks/check_cluster_status.sh`
2. Verifique os logs dos containers: `docker compose logs -f`
3. Certifique-se de que as dependências Python estão instaladas

### Performance inconsistente

1. Execute os testes com cache frio usando os scripts de automação
2. Aumente o número de execuções nos scripts para melhor média
3. Verifique recursos do sistema (CPU, memória, disco)

## Documentação Adicional

- **[Framework de Testes](../pytest/README.md)**: Arquitetura e design dos testes
- **[Arquitetura](../pytest/ARCHITECTURE.md)**: Estrutura do código de testes
- **[Casos de Uso](CASOS-DE-USO.md)**: Exemplos práticos de cenários de teste
