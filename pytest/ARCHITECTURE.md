# 🎯 Visão Geral da Nova Estrutura

## 📊 Organização Refatorada

A estrutura foi reorganizada seguindo o padrão **src/tests** que você utiliza, separando:
- **Código fonte** (src/) - Reutilizável e modular
- **Testes** (tests/) - Organizados por categoria
- **Configuração** (raiz) - pytest.ini, requirements.txt

```
pytest/
├── 📋 pytest.ini           # Configuração
├── 📋 requirements.txt     # Dependências
├── 📘 README.md            # Documentação
│
├── 📂 src/                 # CÓDIGO FONTE
│   ├── 📂 core/           # ⚙️ Funções utilitárias (managers)
│   ├── 📂 models/         # 📦 Modelos de dados (dataclasses)
│   ├── 📂 collectors/     # 🔍 Coletores de métricas
│   └── 📂 fixtures/       # 🔧 Fixtures pytest organizadas
│
├── 📂 tests/              # TESTES
│   ├── conftest.py        # Importa fixtures do src/
│   ├── 📂 resilience/     # 3.4.1 - RTO e RPO
│   └── 📂 performance/    # 3.4.2 - TPS e Latência
│
└── 📂 outputs/            # RESULTADOS (JSONL)
    ├── 📂 resilience/
    └── 📂 performance/
```

---

## 🏗️ Camadas da Arquitetura

### Camada 1: Core (src/core/)
**Responsabilidade**: Operações básicas reutilizáveis

```python
DockerManager         # Gerencia containers Docker
PatroniManager        # Gerencia cluster Patroni
PostgresManager       # Conexões e queries PostgreSQL
PgPoolManager         # Operações PgPool-II
JSONManager           # Leitura/escrita JSONL
```

**Exemplo de uso**:
```python
from src.core.docker_manager import DockerManager

docker = DockerManager()
docker.stop_container("patroni1")
docker.start_container("patroni1")
```

---

### Camada 2: Models (src/models/)
**Responsabilidade**: Estruturas de dados (dataclasses)

```python
RTOMetrics            # Métricas de RTO
RPOMetrics            # Métricas de RPO
PerformanceMetrics    # Métricas de TPS/Latência
LoadTestSummary       # Comparação baseline vs cluster
```

**Exemplo de uso**:
```python
from src.models.rto_metrics import RTOMetrics

metrics = RTOMetrics(
    run_id="abc123",
    test_case="primary_failure",
    failed_node="patroni1"
)
metrics.calculate_metrics()
print(metrics.total_rto)  # 15.8
```

---

### Camada 3: Collectors (src/collectors/)
**Responsabilidade**: Coletar e processar métricas

```python
RTOCollector          # Coleta métricas RTO
RPOCollector          # Coleta métricas RPO
PerformanceCollector  # Executa pgbench e coleta métricas
```

**Exemplo de uso**:
```python
from src.collectors.rto_collector import RTOCollector

rto = RTOCollector(run_id="abc123")
rto.start_measurement("test", "patroni1", "stop")
rto.mark_failure_detected()
rto.mark_new_primary_elected("patroni2")
rto.mark_service_restored()

metrics = rto.get_metrics()  # RTOMetrics object
```

---

### Camada 4: Fixtures (src/fixtures/)
**Responsabilidade**: Preparar objetos para testes (pytest)

```python
# src/fixtures/cluster.py
patroni_manager()     # PatroniManager compartilhado
postgres_manager()    # PostgresManager compartilhado
cluster_healthy()     # Valida cluster antes do teste

# src/fixtures/collectors.py
rto_collector()       # RTOCollector por teste
rpo_collector()       # RPOCollector por teste
performance_collector()  # PerformanceCollector por teste

# src/fixtures/writers.py
rto_writer()          # JSONLWriter para RTO
rpo_writer()          # JSONLWriter para RPO
performance_writer()  # JSONLWriter para performance
```

---

### Camada 5: Tests (tests/)
**Responsabilidade**: Casos de teste organizados

```
tests/
├── conftest.py              # Importa fixtures de src/fixtures/
│
├── resilience/              # 🛡️ Testes de Resiliência
│   ├── test_rto_primary_failure.py
│   ├── test_rto_replica_failure.py
│   ├── test_rpo_primary_failure.py
│   └── test_network_partition.py
│
└── performance/             # ⚡ Testes de Performance
    ├── test_baseline_single_node.py
    ├── test_cluster_with_pgpool.py
    ├── test_read_scalability.py
    └── test_write_performance.py
```

---

## 🔄 Fluxo de Execução

```
1. pytest inicia
   ↓
2. Lê pytest.ini
   ↓
3. Carrega tests/conftest.py
   ↓
4. Importa fixtures de src/fixtures/*.py
   ↓
5. Fixtures criam objetos (Collectors, Managers, Writers)
   ↓
6. Executa testes em tests/resilience/ ou tests/performance/
   ↓
7. Testes usam:
   - Collectors (src/collectors/)
   - Managers (src/core/)
   - Models (src/models/)
   ↓
8. Salva resultados em outputs/ (via Writers)
```

---

## 🎯 Casos de Teste Implementados

### 3.4.1 - Resiliência

| Teste | Arquivo | Métrica | SLA |
|-------|---------|---------|-----|
| RTO - Falha Primário | `test_rto_primary_failure.py` | RTO | < 60s |
| RPO - Falha Primário | `test_rpo_primary_failure.py` | RPO | 0 (sem perda) |

### 3.4.2 - Performance

| Teste | Arquivo | Cenário | Workload |
|-------|---------|---------|----------|
| Baseline SELECT | `test_baseline_single_node.py` | Single Node | SELECT-only |
| Baseline Mixed | `test_baseline_single_node.py` | Single Node | Leitura + Escrita |
| Cluster SELECT | `test_cluster_with_pgpool.py` | HA + PgPool | SELECT-only |
| Cluster Mixed | `test_cluster_with_pgpool.py` | HA + PgPool | Leitura + Escrita |

---

## 📝 Como Adicionar Novos Testes

### 1. Teste de Resiliência (RTO)

```python
# tests/resilience/test_rto_replica_failure.py

import pytest
from src.core.docker_manager import DockerManager

@pytest.mark.rto
@pytest.mark.resilience
class TestRTOReplicaFailure:
    
    def test_replica_failure(
        self,
        rto_collector,      # ← Fixture automática
        rto_writer,         # ← Fixture automática
        get_replica_nodes   # ← Fixture automática
    ):
        docker = DockerManager()
        
        # 1. Identifica réplica
        replicas = get_replica_nodes()
        replica = replicas[0]
        
        # 2. Inicia medição
        metrics = rto_collector.start_measurement("replica_failure", replica)
        
        # 3. Injeta falha
        docker.stop_container(replica)
        rto_collector.mark_failure_detected()
        
        # 4. Aguarda recuperação
        rto_collector.wait_for_service_available()
        rto_collector.mark_service_restored()
        
        # 5. Salva métricas
        metrics = rto_collector.get_metrics()
        rto_writer.write(metrics)
        
        # 6. Valida
        assert metrics.total_rto < 30  # SLA mais agressivo para réplica
        
        # 7. Cleanup
        docker.start_container(replica)
```

### 2. Teste de Performance

```python
# tests/performance/test_read_scalability.py

import pytest

@pytest.mark.performance
@pytest.mark.cluster
class TestReadScalability:
    
    def test_scaling_with_replicas(
        self,
        performance_collector,
        performance_writer
    ):
        # Teste com diferentes números de clientes
        for clients in [10, 50, 100]:
            metrics = performance_collector.run_pgbench(
                test_case=f"scalability_{clients}clients",
                scenario="cluster",
                clients=clients,
                duration=30,
                workload="select-only"
            )
            
            performance_writer.write(metrics)
            
            print(f"Clientes: {clients} → TPS: {metrics.tps_total:.2f}")
```

---

## 🚀 Comandos Úteis

```bash
# Executar por categoria
pytest -m resilience -v        # Todos testes de resiliência
pytest -m rto -v               # Apenas RTO
pytest -m rpo -v               # Apenas RPO
pytest -m performance -v       # Todos testes de performance
pytest -m baseline -v          # Apenas baseline
pytest -m cluster -v           # Apenas cluster

# Executar arquivo específico
pytest tests/resilience/test_rto_primary_failure.py -v -s

# Executar teste específico
pytest tests/resilience/test_rto_primary_failure.py::TestRTOPrimaryFailure::test_primary_node_complete_failure -v -s

# Gerar relatório HTML
pytest -m resilience --html=report.html --self-contained-html

# Modo verbose com output
pytest -m rto -v -s
```

---

## 📊 Vantagens da Estrutura

### ✅ Separação de Responsabilidades
- **src/core**: Funções reutilizáveis (1 responsabilidade cada)
- **src/models**: Apenas dados (sem lógica)
- **src/collectors**: Apenas coleta de métricas
- **tests/**: Apenas casos de teste

### ✅ Escalabilidade
- Fácil adicionar novos testes sem duplicar código
- Managers são reutilizados entre todos os testes
- Fixtures organizadas por categoria

### ✅ Manutenibilidade
- Código core está isolado em src/
- Testes não misturam com implementação
- Fácil encontrar e modificar funcionalidades

### ✅ Testabilidade
- Cada manager pode ser testado isoladamente
- Fixtures facilitam setup/teardown
- Menos código duplicado = menos bugs

---

## 🎓 Conceitos-Chave

### Fixture vs Manager
```python
# Manager = Classe com lógica
class PatroniManager:
    def get_primary_node(self):
        # Lógica aqui
        pass

# Fixture = Prepara objeto para teste
@pytest.fixture
def patroni_manager():
    return PatroniManager()  # ← Cria e retorna
```

### Collector vs Manager
```python
# Manager = Operações básicas
class DockerManager:
    def stop_container(self, name):
        pass

# Collector = Orquestra managers + coleta métricas
class RTOCollector:
    def __init__(self):
        self.docker = DockerManager()
        self.patroni = PatroniManager()
        self.metrics = RTOMetrics(...)
```

---

## 📚 Próximos Passos

1. ✅ Estrutura base criada
2. ✅ Testes RTO e RPO implementados
3. ✅ Testes de performance implementados
4. ⏭️ Adicionar testes de rede (network partition)
5. ⏭️ Adicionar testes de falha de réplica
6. ⏭️ Criar dashboard de visualização dos resultados
7. ⏭️ Integrar com CI/CD

---

**Estrutura criada**: ✅  
**Testes funcionais**: ✅  
**Documentação completa**: ✅  
**Pronto para uso**: ✅
