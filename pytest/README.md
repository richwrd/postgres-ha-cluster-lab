# Testes de HA PostgreSQL Cluster

Framework de testes automatizados para avaliar **Resiliência** e **Performance** do cluster PostgreSQL HA com Patroni e PgPool-II.

## 📁 Estrutura do Projeto

```
tests/
├── pytest.ini                    # Configuração do pytest
├── requirements.txt              # Dependências Python
├── README.md                     # Esta documentação
│
├── src/                          # Código fonte
│   ├── core/                     # Funções utilitárias core
│   │   ├── config.py            # Configuração e variáveis de ambiente
│   │   ├── json_manager.py      # Gerenciamento de JSONL
│   │   ├── docker_manager.py    # Operações Docker
│   │   ├── patroni_manager.py   # Operações Patroni
│   │   ├── postgres_manager.py  # Conexões PostgreSQL
│   │   └── pgpool_manager.py    # Operações PgPool
│   │
│   ├── models/                   # Modelos de dados
│   │   ├── rto_metrics.py       # Métricas RTO
│   │   ├── rpo_metrics.py       # Métricas RPO
│   │   └── performance_metrics.py  # Métricas de performance
│   │
│   ├── collectors/               # Coletores de métricas
│   │   ├── rto_collector.py     # Coletor RTO
│   │   ├── rpo_collector.py     # Coletor RPO
│   │   └── performance_collector.py  # Coletor de performance
│   │
│   └── fixtures/                 # Fixtures pytest
│       ├── cluster.py           # Fixtures do cluster
│       ├── collectors.py        # Fixtures de collectors
│       └── writers.py           # Fixtures de writers
│
├── tests/                        # Testes organizados por categoria
│   ├── conftest.py              # Configuração global pytest
│   │
│   ├── resilience/              # 3.4.1 - Testes de Resiliência
│   │   ├── test_rto_primary_failure.py
│   │   └── test_rpo_primary_failure.py
│   │
│   └── performance/             # 3.4.2 - Testes de Performance
│       ├── test_baseline_single_node.py
│       └── test_cluster_with_pgpool.py
│
└── outputs/                     # Resultados dos testes (JSONL)
    ├── resilience/              # RTO e RPO
    └── performance/             # TPS e Latência
```

---

## 🎯 Casos de Teste Implementados

### 3.4.1 - Testes de Resiliência

#### RTO (Recovery Time Objective)
- ✅ **test_rto_primary_failure.py**: Falha completa do nó primário
  - Simula: `docker stop patroni-postgres-1`
  - Mede: Tempo até novo primário responder
  - SLA: RTO < 60 segundos

#### RPO (Recovery Point Objective)
- ✅ **test_rpo_primary_failure.py**: Verificação de perda de dados
  - Escreve transações antes da falha
  - Verifica recuperação após failover
  - SLA: RPO = 0 (sem perda de dados)

### 3.4.2 - Testes de Performance

#### Baseline (Single Node)
- ✅ **test_baseline_select_only**: pgbench SELECT-only
  - Parâmetros: 10 clientes, 4 threads, 60s
  - Workload: Somente leitura
  
- ✅ **test_baseline_mixed**: pgbench mixed workload
  - Parâmetros: 10 clientes, 4 threads, 60s
  - Workload: Leitura + escrita

#### Cluster HA (com PgPool)
- ✅ **test_cluster_select_only_with_pgpool**: pgbench via PgPool
  - Parâmetros: 10 clientes, 4 threads, 60s
  - Load balancing habilitado
  
- ✅ **test_cluster_mixed_with_pgpool**: pgbench mixed via PgPool
  - Parâmetros: 10 clientes, 4 threads, 60s
  - Distribui carga entre réplicas

---

## 🚀 Instalação

### 1. Configuração do Ambiente

Os testes leem automaticamente as configurações do arquivo `.env` na **raiz do projeto** (não do diretório pytest).

```bash
# .env deve conter os nomes dos containers:
ETCD1_NAME=etcd-1
ETCD2_NAME=etcd-2
ETCD3_NAME=etcd-3

PATRONI1_NAME=patroni-postgres-1
PATRONI2_NAME=patroni-postgres-2
PATRONI3_NAME=patroni-postgres-3
PGPOOL_NAME=pgpool
```

**Importante**: O arquivo `.env` deve estar em `postgres-ha-cluster-lab/.env` (raiz do projeto).

### 2. Instalar Dependências

```bash
# Navegar para diretório de testes
cd pytest

# Instalar dependências
pip install -r requirements.txt
```

### 3. Validar Configuração

```bash
# Executar teste de configuração
pytest tests/test_config.py -v

# Output esperado:
# test_config.py::test_config_loads_env PASSED
# test_config.py::test_patroni_node_names PASSED
# test_config.py::test_etcd_node_names PASSED
# test_config.py::test_pgpool_name PASSED
```

---

## 🧪 Executando os Testes

### Pré-requisitos
```bash
# 1. Cluster deve estar rodando
docker compose up -d

# 2. Criar usuário de teste no PostgreSQL (se ainda não criado)
sudo ./scripts/create_superuser.sh

# 3. Verificar saúde do cluster
sudo ./scripts/health_checks/check_cluster_health.sh
```

### Comandos Principais

```bash
# Todos os testes de resiliência (RTO + RPO)
pytest -m resilience -v

# Apenas testes de RTO
pytest -m rto -v

# Apenas testes de RPO
pytest -m rpo -v

# Todos os testes de performance
pytest -m performance -v

# Apenas baseline
pytest -m baseline -v

# Apenas cluster
pytest -m cluster -v

# Teste específico
pytest tests/resilience/test_rto_primary_failure.py::TestRTOPrimaryFailure::test_primary_node_complete_failure -v -s

# Gerar relatório HTML
pytest -m resilience --html=report.html --self-contained-html
```

---

## 📊 Formato de Saída

Os testes geram arquivos JSONL em `outputs/`:

```
outputs/
├── resilience/
│   ├── rto_20251018_100000_a1b2c3d4.jsonl
│   └── rpo_20251018_100000_a1b2c3d4.jsonl
└── performance/
    └── performance_20251018_100000_a1b2c3d4.jsonl
```

### Exemplo de Métricas RTO

```json
{
  "run_id": "20251018_100000_a1b2c3d4",
  "test_case": "primary_complete_failure",
  "failure_type": "stop",
  "failed_node": "patroni1",
  "new_primary_node": "patroni2",
  "detection_time": 3.5,
  "election_time": 8.8,
  "restoration_time": 3.5,
  "total_rto": 15.8
}
```

---

## 🏗️ Guia de Desenvolvimento

### Criar Novo Teste RTO

```python
import pytest
from src.core.docker_manager import DockerManager

@pytest.mark.rto
class TestRTO:
    def test_my_scenario(self, rto_collector, rto_writer, get_primary_node):
        docker = DockerManager()
        
        # 1. Setup
        primary = get_primary_node()
        
        # 2. Medição
        metrics = rto_collector.start_measurement("my_test", primary)
        docker.stop_container(primary)
        rto_collector.mark_failure_detected()
        
        # 3. Recuperação
        new_primary = rto_collector.wait_for_new_primary()
        rto_collector.mark_new_primary_elected(new_primary)
        rto_collector.wait_for_service_available()
        rto_collector.mark_service_restored()
        
        # 4. Validação
        metrics = rto_collector.get_metrics()
        rto_writer.write(metrics)
        assert metrics.total_rto < 60
        
        # 5. Cleanup
        docker.start_container(primary)
```

### Criar Novo Teste de Performance

```python
import pytest

@pytest.mark.performance
class TestPerf:
    def test_my_workload(self, performance_collector, performance_writer):
        # Inicializar database
        performance_collector.initialize_pgbench_database(scale=10)
        
        # Executar teste
        metrics = performance_collector.run_pgbench(
            test_case="my_test",
            scenario="baseline",
            clients=10,
            duration=60,
            workload="select-only"
        )
        
        # Salvar e validar
        performance_writer.write(metrics)
        assert metrics.tps_total > 0
```

---

## 📚 API Principal

### Core Managers

**DockerManager**
```python
docker = DockerManager()
docker.stop_container("patroni1")
docker.start_container("patroni1")
docker.restart_container("patroni1")
docker.is_running("patroni1")
```

**PatroniManager**
```python
patroni = PatroniManager()
primary = patroni.get_primary_node()
replicas = patroni.get_replica_nodes()
is_healthy = patroni.is_cluster_healthy()
```

**PostgresManager**
```python
pg = PostgresManager(host="localhost", port=5432)
available = pg.is_available()
pg.wait_until_available(max_wait=60)
pg.execute_query("SELECT 1")
```

### Collectors

**RTOCollector**
```python
rto = RTOCollector(run_id)
rto.start_measurement("test", "patroni1", "stop")
rto.mark_failure_detected()
rto.mark_new_primary_elected("patroni2")
rto.mark_service_restored()
metrics = rto.get_metrics()
```

**PerformanceCollector**
```python
perf = PerformanceCollector(run_id)
metrics = perf.run_pgbench(
    test_case="test",
    scenario="baseline",
    clients=10,
    duration=60,
    workload="select-only"
)
```

---

## 🔧 Troubleshooting

```bash
# Cluster não está saudável
docker exec patroni1 patronictl list
docker-compose restart

# Módulo src não encontrado
cd tests && pytest -v

# pgbench não encontrado
sudo apt-get install postgresql-client
```

---

**Versão**: 0.1.0
