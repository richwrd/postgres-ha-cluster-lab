# Docker Stats Collector - Documentação

## Visão Geral

O `DockerStatsCollector` coleta estatísticas de containers Docker durante a execução de testes pytest, calculando médias de CPU, memória, rede e I/O de disco.

## Componentes

### 1. **DockerStatsCollector** (`src/collectors/docker_stats_collector.py`)
Coleta estatísticas em background thread durante a execução do teste.

### 2. **DockerStatsMetrics** (`src/models/docker_stats_metrics.py`)
Modelos de dados para armazenar as métricas coletadas.

### 3. **Fixtures Pytest** (`src/fixtures/collectors.py` e `writers.py`)
- `docker_stats_collector`: Cria e gerencia o coletor
- `docker_stats_writer`: Salva métricas em arquivo JSONL

## Como Usar

### Opção 1: Modo Automático (Recomendado)

Use o marcador `@pytest.mark.monitor_containers` para iniciar/parar automaticamente:

```python
import pytest

@pytest.mark.monitor_containers(["postgres-1", "pgpool-1"])
def test_example(docker_stats_collector, docker_stats_writer):
    """Coleta automaticamente durante todo o teste"""
    
    # Seu código de teste aqui
    # ...
    
    # No final, obter métricas
    metrics = docker_stats_collector.get_metrics("test_example")
    docker_stats_writer.write(metrics.to_dict())
```

**Com intervalo customizado:**

```python
@pytest.mark.monitor_containers(["postgres-1"], interval=1.0)  # coleta a cada 1s
def test_example(docker_stats_collector, docker_stats_writer):
    # ...
    pass
```

### Opção 2: Modo Manual

Controle completo sobre início/parada da coleta:

```python
def test_example(docker_stats_collector, docker_stats_writer):
    """Controle manual da coleta"""
    
    # Criar coletor
    containers = ["postgres-1", "pgpool-1", "patroni-1"]
    collector = docker_stats_collector(containers, interval=2.0)
    
    # Iniciar coleta
    collector.start()
    
    # Executar teste
    # ... seu código aqui ...
    
    # Parar coleta
    collector.stop()
    
    # Obter métricas
    metrics = collector.get_metrics("test_example")
    
    # Salvar
    docker_stats_writer.write(metrics.to_dict())
    
    # Exibir (opcional)
    print_docker_stats(metrics)
```

### Opção 3: Coleta Parcial (Apenas parte do teste)

```python
def test_example(docker_stats_collector, docker_stats_writer):
    """Coleta apenas durante execução de carga"""
    
    # Setup (sem coleta)
    setup_database()
    
    # Criar e iniciar coletor
    collector = docker_stats_collector(["postgres-1"])
    collector.start()
    
    # Fase de teste (COM coleta)
    run_workload()
    
    # Parar coleta
    collector.stop()
    
    # Teardown (sem coleta)
    cleanup()
    
    # Salvar métricas
    metrics = collector.get_metrics("test_example_workload")
    docker_stats_writer.write(metrics.to_dict())
```

## Métricas Coletadas

Para cada container monitorado:

- **CPU**:
  - Percentual médio
  - Percentual máximo

- **Memória**:
  - Uso médio (bytes e %)
  - Uso máximo (bytes e %)

- **Rede**:
  - Total recebido (RX)
  - Total transmitido (TX)

- **Disco**:
  - Total lido
  - Total escrito

- **Metadados**:
  - Número de amostras
  - Duração da coleta
  - Timestamp início/fim

## Estrutura de Saída

Os dados são salvos em formato JSONL em:
```
outputs/
  performance/
    baseline/
      docker_stats_<run_id>.jsonl
    cluster/
      docker_stats_<run_id>.jsonl
  resilience/
    rto/
      docker_stats_<run_id>.jsonl
    rpo/
      docker_stats_<run_id>.jsonl
```

### Exemplo de JSON:

```json
{
  "test_name": "baseline_select_only_80clients",
  "start_time": "2025-10-21T14:30:00.123456",
  "end_time": "2025-10-21T14:31:05.789012",
  "duration_seconds": 65.67,
  "containers": {
    "postgres-baseline": {
      "container_name": "postgres-baseline",
      "cpu_percent_avg": 45.23,
      "cpu_percent_max": 78.45,
      "memory_usage_mb_avg": 1024.50,
      "memory_usage_mb_max": 1256.78,
      "memory_percent_avg": 6.25,
      "memory_percent_max": 7.68,
      "network_rx_mb_total": 125.34,
      "network_tx_mb_total": 98.76,
      "block_read_mb_total": 456.12,
      "block_write_mb_total": 234.56,
      "sample_count": 33,
      "duration_seconds": 65.67
    },
    "pgbench-client": {
      "container_name": "pgbench-client",
      "cpu_percent_avg": 12.34,
      "cpu_percent_max": 25.67,
      "memory_usage_mb_avg": 128.45,
      "memory_usage_mb_max": 156.78,
      "memory_percent_avg": 0.78,
      "memory_percent_max": 0.96,
      "network_rx_mb_total": 98.76,
      "network_tx_mb_total": 125.34,
      "block_read_mb_total": 12.34,
      "block_write_mb_total": 5.67,
      "sample_count": 33,
      "duration_seconds": 65.67
    }
  }
}
```

## Exemplo Completo

Ver implementação em: `pytest/tests/performance/test_baseline_single_node.py`

```python
@pytest.mark.parametrize("client_count", [10, 20, 40, 80])
def test_baseline_select_only(
    self,
    client_count,
    performance_collector,
    performance_writer_baseline,
    docker_stats_collector,
    docker_stats_writer
):
    """Teste com coleta de métricas de performance e Docker Stats"""
    
    # Containers a monitorar
    containers = ["postgres-baseline", "pgbench-client"]
    
    # Iniciar coleta Docker Stats
    stats_collector = docker_stats_collector(containers, interval=2.0)
    stats_collector.start()
    
    # Executar teste de performance
    metrics = performance_collector.run_pgbench(
        test_case=f"baseline_select_only_{client_count}clients",
        # ... parâmetros ...
    )
    
    # Parar coleta Docker Stats
    stats_collector.stop()
    docker_metrics = stats_collector.get_metrics(
        f"baseline_select_only_{client_count}clients"
    )
    
    # Salvar ambas as métricas
    performance_writer_baseline.write(metrics)
    docker_stats_writer.write(docker_metrics.to_dict())
    
    # Exibir resultados
    print_performance_metrics(metrics)
    print_docker_stats(docker_metrics)
```

## Funções Auxiliares

### Exibir Estatísticas Docker

```python
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
        print(f"    Média:  {stats.memory_usage_bytes_avg / (1024**2):.2f} MB")
        print(f"    Máxima: {stats.memory_usage_bytes_max / (1024**2):.2f} MB")
        print(f"  Rede:")
        print(f"    RX: {stats.network_rx_bytes_total / (1024**2):.2f} MB")
        print(f"    TX: {stats.network_tx_bytes_total / (1024**2):.2f} MB")
        print(f"  Disco:")
        print(f"    Read:  {stats.block_read_bytes_total / (1024**2):.2f} MB")
        print(f"    Write: {stats.block_write_bytes_total / (1024**2):.2f} MB")
        print(f"  Amostras: {stats.sample_count}")
```

## Configurações

### Intervalo de Coleta

- **Padrão**: 2 segundos
- **Recomendado para testes rápidos** (<30s): 1 segundo
- **Recomendado para testes longos** (>5min): 5 segundos

```python
# Alta frequência (mais amostras)
collector = docker_stats_collector(containers, interval=1.0)

# Baixa frequência (menos overhead)
collector = docker_stats_collector(containers, interval=5.0)
```

### Overhead

- **Thread em background**: Minimal
- **Comando docker stats**: ~50-100ms por coleta
- **Impacto no teste**: Negligível (<1%)

## Dicas

1. **Containers válidos**: Use apenas containers em execução
2. **Nomes completos**: Use nomes exatos dos containers
3. **Múltiplos testes**: Chame `collector.reset()` entre testes
4. **Análise posterior**: Use os arquivos JSONL para análise agregada

## Troubleshooting

### Container não encontrado
```
❌ Erro ao obter stats: ...
```
**Solução**: Verifique se o container está rodando com `docker ps`

### Métricas zeradas
```
All metrics are 0.0
```
**Solução**: Container pode estar idle ou parado durante coleta

### Thread não para
```
Coleta continua após teste
```
**Solução**: Sempre chame `collector.stop()` no final ou use modo automático
