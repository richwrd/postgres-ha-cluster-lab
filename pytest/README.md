# Testes de HA PostgreSQL Cluster

Framework de testes automatizados para **Resiliência** e **Performance** do cluster PostgreSQL HA com Patroni e PgPool-II.

## 📁 Estrutura

```
tests/
├── src/
│   ├── core/          # Config, Docker, Patroni, PostgreSQL, PgPool
│   ├── models/        # Métricas RTO, RPO, Performance
│   ├── collectors/    # Coletores de métricas
│   └── fixtures/      # Fixtures pytest
│
├── tests/
│   ├── resilience/    # RTO e RPO
│   └── performance/   # Baseline e Cluster
│
└── outputs/           # Resultados JSONL
```

## 🎯 Casos de Teste

### Resiliência
- **test_rto_primary_failure**: Mede tempo até novo primário (SLA: < 60s)
- **test_rpo_primary_failure**: Verifica perda de dados (SLA: RPO = 0)

### Performance
- **test_baseline_select_only**: pgbench SELECT-only
- **test_cluster_select_only_with_pgpool**: pgbench SELECT-only Load balancing

## 🚀 Setup

```bash
# 1. Instalar dependências
cd pytest && pip install -r requirements.txt

# 2. Configurar .env na raiz do projeto
PATRONI1_NAME=patroni-postgres-1
PATRONI2_NAME=patroni-postgres-2
PATRONI3_NAME=patroni-postgres-3
PGPOOL_NAME=pgpool

# 3. Iniciar cluster
docker compose up -d

# 4. Criar usuário teste
sudo ./scripts/create_superuser.sh
```

## 🧪 Executar Testes

```bash
# Resiliência
pytest -m resilience -v

# Performance
pytest -m performance -v

# Teste específico
pytest tests/resilience/test_rto_primary_failure.py -v

# Relatório HTML
pytest --html=report.html --self-contained-html
```

## 📊 Saída

Arquivos JSONL em `outputs/`:

```json
{
  "run_id": "20251018_100000",
  "test_case": "primary_failure",
  "total_rto": 22.10,
  "new_primary_node": "patroni2"
}
```

## 🔧 API Principal

```python
# Docker
docker.stop_container("patroni1")

# Patroni
primary = patroni.get_primary_node()

# PostgreSQL
pg.wait_until_available(max_wait=60)

# RTO
rto.start_measurement("test", "patroni1")
metrics = rto.get_metrics()

# Performance
metrics = perf.run_pgbench(clients=10, duration=60)
```

## 🔍 Troubleshooting

```bash
# Verificar cluster
docker exec patroni1 patronictl list

# Resetar
docker compose restart
```
