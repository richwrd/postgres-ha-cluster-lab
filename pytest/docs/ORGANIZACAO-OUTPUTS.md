# Organização de Outputs - Arquivos JSONL

## Visão Geral

Os arquivos JSONL gerados pelos testes são organizados em uma estrutura hierárquica que facilita a análise e navegação dos resultados.

## Estrutura de Diretórios

### Testes de Performance - Baseline

```
outputs/
└── performance/
    └── baseline/
        ├── select_only/
        │   ├── 10/
        │   │   ├── performance_YYYYMMDD_HHMMSS_<run_id>.jsonl
        │   │   └── docker_stats_YYYYMMDD_HHMMSS_<run_id>.jsonl
        │   ├── 25/
        │   ├── 50/
        │   ├── 75/
        │   └── 100/
        ├── select_only_reconnect/
        │   ├── 10/
        │   ├── 25/
        │   ├── 50/
        │   ├── 75/
        │   └── 100/
        ├── mixed/
        │   ├── 10/
        │   ├── 25/
        │   ├── 50/
        │   ├── 75/
        │   └── 100/
        └── mixed_reconnect/
            ├── 10/
            ├── 25/
            ├── 50/
            ├── 75/
            └── 100/
```

### Testes de Performance - Cluster

```
outputs/
└── performance/
    └── cluster/
        ├── select_only/
        │   ├── 10/
        │   │   ├── performance_YYYYMMDD_HHMMSS_<run_id>.jsonl
        │   │   └── docker_stats_YYYYMMDD_HHMMSS_<run_id>.jsonl
        │   ├── 25/
        │   ├── 50/
        │   ├── 75/
        │   └── 100/
        ├── select_only_reconnect/
        │   └── ...
        ├── mixed/
        │   └── ...
        └── mixed_reconnect/
            └── ...
```

### Testes de Resiliência

```
outputs/
└── resilience/
    ├── rto/
    │   ├── rto_YYYYMMDD_HHMMSS_<run_id>.jsonl
    │   └── docker_stats_YYYYMMDD_HHMMSS_<run_id>.jsonl
    └── rpo/
        ├── rpo_YYYYMMDD_HHMMSS_<run_id>.jsonl
        └── docker_stats_YYYYMMDD_HHMMSS_<run_id>.jsonl
```

## Benefícios da Organização

### 1. Facilita Comparações
- Compare facilmente o desempenho do mesmo workload com diferentes números de clientes
- Visualize rapidamente o impacto do reconnect flag

### 2. Navegação Intuitiva
- Estrutura auto-explicativa
- Fácil localização de resultados específicos

### 3. Análise Direcionada
- Analise apenas o subset relevante de dados
- Organize scripts de análise por workload/client count

### 4. Gerenciamento de Armazenamento
- Fácil limpeza de resultados antigos por categoria
- Permite backup seletivo por tipo de teste

## Tipos de Workload

### Performance - Baseline e Cluster

| Workload | Descrição |
|----------|-----------|
| `select_only` | Apenas leituras (SELECT) |
| `select_only_reconnect` | Apenas leituras com reconexão por transação (-C flag) |
| `mixed` | Workload misto (leitura/escrita) |
| `mixed_reconnect` | Workload misto com reconexão por transação (-C flag) |

### Client Counts Padrão

- 10 clientes
- 25 clientes
- 50 clientes
- 75 clientes
- 100 clientes

## Convenção de Nomes de Arquivos

### Performance
```
performance_YYYYMMDD_HHMMSS_<run_id>.jsonl
```

### Docker Stats
```
docker_stats_YYYYMMDD_HHMMSS_<run_id>.jsonl
```

### RTO/RPO
```
rto_YYYYMMDD_HHMMSS_<run_id>.jsonl
rpo_YYYYMMDD_HHMMSS_<run_id>.jsonl
```

Onde:
- `YYYYMMDD_HHMMSS`: Timestamp UTC do início do teste
- `<run_id>`: ID único do run (gerado automaticamente)

## Implementação Técnica

### JSONLWriter

A classe `JSONLWriter` foi atualizada para aceitar subdiretórios opcionais:

```python
writer = JSONLWriter(
    output_dir=base_dir,
    prefix="performance",
    run_id=run_id,
    subdirs=["select_only", "10"]  # Opcional
)
```

### Fixtures de Escrita

As fixtures `performance_writer_baseline`, `performance_writer_cluster` e `docker_stats_writer` foram atualizadas para:

1. Extrair automaticamente o tipo de workload dos marcadores pytest
2. Extrair o número de clientes dos parâmetros do teste
3. Criar a estrutura de diretórios apropriada

**Importante**: Nenhuma alteração é necessária nos testes existentes! As fixtures detectam automaticamente as informações necessárias.

## Exemplos de Uso

### Análise de Escalabilidade

Para comparar o desempenho de `select_only` com diferentes números de clientes:

```bash
# Baseline
ls outputs/performance/baseline/select_only/*/performance_*.jsonl

# Cluster
ls outputs/performance/cluster/select_only/*/performance_*.jsonl
```

### Análise de Impacto do Reconnect

Compare workloads com e sem reconnect:

```bash
# Sem reconnect
outputs/performance/baseline/select_only/50/

# Com reconnect
outputs/performance/baseline/select_only_reconnect/50/
```

### Docker Stats por Workload

```bash
# Docker stats de todos os testes select_only
find outputs/performance -path "*/select_only/*/docker_stats_*.jsonl"
```

## Migração de Dados Antigos

Os arquivos JSONL na estrutura antiga (sem subdiretórios) continuarão acessíveis em:
- `docs/old/`

Novos testes usarão automaticamente a nova estrutura hierárquica.
