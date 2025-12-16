# Quick Start

Guia rápido para configurar e executar o cluster PostgreSQL de Alta Disponibilidade.

## Pré-requisitos

- **Docker** 20.10+
- **Docker Compose** v2.20+ (com suporte a `include`)
- **Python** 3.10+ (para testes)
- **Git**
- **Recursos mínimos recomendados**:
  - 4 CPU cores
  - 8GB RAM
  - 20GB disco disponível

## Instalação

### 1. Clone o Repositório

```bash
git clone https://github.com/richwrd/postgres-ha-cluster-lab
cd postgres-ha-cluster-lab
```

### 2. Configure as Variáveis de Ambiente

#### Arquivo `.env` na raiz do projeto

```bash
# Copie o arquivo de exemplo
cp .env.example .env

# Edite conforme necessário
```

#### Arquivo `.env` em `infra/patroni-postgres/`

```bash
# Configurações específicas do Patroni e PostgreSQL
# Copie o arquivo de exemplo se disponível
cp infra/patroni-postgres/.env.example infra/patroni-postgres/.env

# Edite conforme necessário
```

#### Arquivo `.env` em `infra/pgpool/`

```bash
# Configurações específicas do PgPool-II
# Copie o arquivo de exemplo se disponível
cp infra/pgpool/.env.example infra/pgpool/.env

# Edite conforme necessário
```

### 3. Crie os Diretórios de Dados

```bash
./scripts/create_data_dirs.sh
```

### 4. Suba a Infraestrutura

```bash
# Sobe todos os serviços (etcd, patroni, pgpool)
# Para exporters descomentar o docker compose include correspondente
docker compose up -d

# Verifique o status
docker compose ps
```

### 5. Verifique a Saúde do Cluster

```bash
# Health check completo
./scripts/health_checks/check_cluster_status.sh

# Verificar apenas etcd
./scripts/health_checks/etcd.sh

# Verificar apenas patroni
./scripts/health_checks/patroni.sh

# Verificar apenas pgpool
./scripts/health_checks/pgpool.sh
```

## Scripts Utilitários

```bash
# Criar superusuário
./scripts/create_superuser.sh

# Gerenciar containers
./scripts/container.sh [start|stop|restart|status]
```

## Monitoramento

O projeto inclui exporters Prometheus para coleta de métricas:

- **PostgreSQL Exporter**: Métricas do banco de dados (portas externas 9187-9189)
- **Patroni REST API**: API de status e controle do cluster (portas externas 8008-8010)
- **Etcd Metrics Exporter**: Métricas do etcd (portas externas 2379-2380)
- **PgPool Exporter**: Métricas do PgPool-II (porta externa 9719)

Acesse as métricas:

```bash
# PostgreSQL node 1
curl http://patroni-postgres-1:9187/metrics

# Patroni node 1
curl http://patroni-postgres-1:8008/metrics

# Etcd node 1
curl http://etcd-1:2379/metrics

# PgPool
curl http://pgpool:9719/metrics
```

## Próximos Passos

- Consulte [TESTES.md](TESTES.md) para executar testes de resiliência e performance
- Veja [CASOS-DE-USO.md](CASOS-DE-USO.md) para exemplos práticos de uso do cluster
- Leia a documentação técnica em `docs/stack/` para entender a arquitetura
