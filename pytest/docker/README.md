# Testes de Performance - Baseline

Este diretório contém a infraestrutura para executar testes de performance baseline (PostgreSQL standalone).

## Arquitetura

```
┌─────────────────┐       ┌──────────────────┐
│ pgbench-client  │──────▶│ postgres-baseline│
│  (postgres:17)  │       │   (postgres:17)  │
│                 │       │                  │
│ - Executa testes│       │ - CPU: 4 core    │
│ - CPU: 1 core   │       │ - RAM: 4GB       │
│ - RAM: 2GB      │       │ - Porta: 5432    │
└─────────────────┘       └──────────────────┘
```

## Arquivos

- `docker-compose.pgbench.yaml` - Container cliente para executar pgbench
- `run-baseline-test.sh` - Script automatizado para executar testes

## Como Executar

### Opção 1: Script Automatizado (Recomendado)

```bash
cd pytest/docker
./run-baseline-test.sh
```

Este script:
1. Sobe o PostgreSQL baseline
2. Sobe o container pgbench-client
3. Executa os testes de performance
4. Limpa o ambiente ao final

### Opção 2: Passo a Passo Manual

#### 1. Subir PostgreSQL baseline

```bash
# Na raiz do projeto
docker-compose -f docker-compose.baseline.yaml up -d

# Verificar status
docker-compose -f docker-compose.baseline.yaml ps

# Aguardar ficar saudável
docker exec postgres-baseline pg_isready -U postgres
```

#### 2. Subir container pgbench-client

```bash
cd pytest/docker
docker-compose -f docker-compose.pgbench.yaml up -d

# Verificar status
docker-compose -f docker-compose.pgbench.yaml ps
```

#### 3. Executar testes

```bash
cd pytest
pytest tests/performance/test_baseline_single_node.py -v -s
```

#### 4. Limpar ambiente

```bash
# Na raiz do projeto
docker-compose -f docker-compose.baseline.yaml down -v

# No diretório pytest/docker
cd pytest/docker
docker-compose -f docker-compose.pgbench.yaml down
```

## Testes Disponíveis

### test_baseline_select_only

Teste de performance com workload de **leitura apenas** (SELECT-only).

**Parâmetros:**
- Clientes: 10
- Threads: 4
- Duração: 60s
- Workload: `select-only`
- Scale: 10 (~160MB)

**Métricas coletadas:**
- TPS (Transactions Per Second)
- Latência média (ms)
- Total de transações
- Taxa de sucesso

### test_baseline_mixed_workload

Teste de performance com workload **misto** (leitura + escrita).

**Parâmetros:**
- Clientes: 10
- Threads: 4
- Duração: 60s
- Workload: `mixed` (TPC-B like)
- Usa database já inicializado

## Resultados

Os resultados são salvos em:
```
pytest/outputs/performance/
```

Formato JSON com todas as métricas coletadas.

## Troubleshooting

### Container não inicia

```bash
# Verificar logs do PostgreSQL
docker logs postgres-baseline

# Verificar logs do pgbench-client
docker logs pgbench-client
```

### Erro de conexão

Verifique se os containers estão na mesma rede:

```bash
docker network inspect postgres-baseline-network
```

### pgbench não encontrado

Certifique-se de que o container pgbench-client está usando a imagem `postgres:17`:

```bash
docker exec pgbench-client which pgbench
```

## Limitações de Recursos

### PostgreSQL Baseline
- **CPU:** 1.0 core
- **Memória:** 4GB

### pgbench-client
- **CPU:** 1.0 core
- **Memória:** 2GB

Estas limitações garantem testes consistentes e reproduzíveis.
