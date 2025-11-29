# Cluster PostgreSQL de Alta Disponibilidade com Patroni, etcd e Pgpool-II

Projeto de Trabalho de Conclusão de Curso focado na implementação e análise de uma arquitetura de alta disponibilidade para PostgreSQL usando ferramentas open-source em um ambiente containerizado com Docker.

## 🏛️ Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                    Camada de Aplicação                      │
│                         (Clientes)                          │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                 PgPool-II (Load Balancer)                   │
│              • Balanceamento de Carga (Leitura)             │
│              • Connection Pooling                           │
│              • Query Routing                                │
└─────────┬───────────────┬───────────────┬───────────────────┘
          │               │               │
          ▼               ▼               ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  Patroni 1  │  │  Patroni 2  │  │  Patroni 3  │
│ (Primary)   │  │ (Replica)   │  │ (Replica)   │
├─────────────┤  ├─────────────┤  ├─────────────┤
│ PostgreSQL  │  │ PostgreSQL  │  │ PostgreSQL  │
│   17.x      │  │   17.x      │  │   17.x      │
└──────┬──────┘  └──────┬──────┘  └──────┬──────┘
       │                │                │
       └────────────────┼────────────────┘
                        │
                        ▼
         ┌──────────────────────────────┐
         │      etcd Cluster (DCS)      │
         │  • Consenso Distribuído      │
         │  • Leader Election           │
         │  • Estado do Cluster         │
         └──────────────────────────────┘
```

## 🚀 Sobre o Projeto

Este repositório contém todos os artefatos de código produzidos para o TCC, cujo objetivo é criar e analisar um cluster PostgreSQL resiliente a falhas. A solução utiliza ferramentas open-source em um ambiente totalmente orquestrado via Docker Compose.

### Principais Componentes

* **Cluster PostgreSQL (3 nós)**: Gerenciados pelo **Patroni**, responsável pela replicação streaming assíncrona e failover automático
* **etcd (3 nós)**: Serviço de descoberta distribuído (DCS) que mantém o estado do cluster e coordena a eleição de líder
* **PgPool-II**: Proxy de conexões que fornece balanceamento de carga para leituras e roteamento inteligente de queries
* **Exporters**: Prometheus exporters para PostgreSQL e PgPool-II para monitoramento de métricas

### Funcionalidades Implementadas

✅ **Failover Automático**: Detecção de falhas e promoção automática de réplicas  
✅ **Balanceamento de Carga**: Distribuição de consultas de leitura entre réplicas  
✅ **Replicação Streaming**: Sincronização contínua de dados entre nós  
✅ **Health Checks**: Monitoramento automatizado do cluster  
✅ **Testes de Resiliência**: Framework pytest para testes de RTO e RPO  
✅ **Testes de Performance**: Framework pytest para benchmarks com pgbench para análise de TPS e latência

## 📋 Pré-requisitos

* **Docker** 20.10+
* **Docker Compose** v2.20+ (com suporte a `include`)
* **Python** 3.10+
* **Git**
* **Recursos mínimos recomendados**:
  - 4 CPU cores
  - 8GB RAM
  - 20GB disco disponível

## 🛠️ Quick Start

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

## 🧪 Executando os Testes

### Configurar Ambiente de Testes
```bash
cd pytest

# Criar ambiente virtual
python3 -m venv .venv
source .venv/bin/activate

# Instalar dependências
pip install -r requirements.txt
```

### Testes de Resiliência

**RTO (Recovery Time Objective) - Falha do Nó Primário:**
```bash
# Via script helper
./scripts/test/run-crash-up.sh

# Ou diretamente com pytest
pytest pytest/tests/resilience/test_rto_primary_failure.py::TestRTOPrimaryFailure::test_primary_node_complete_failure -v -s
```

**RPO (Recovery Point Objective):**
```bash
pytest pytest/tests/resilience/test_rpo_primary_failure.py -v -s
```

### Testes de Performance

**Baseline (Nó Único):**
```bash
# SELECT-only workload
pytest pytest/tests/performance/test_baseline_single_node.py::TestPerformanceBaseline::test_baseline_select_only -v -s
```

**Cluster com PgPool:**
```bash
# SELECT-only com balanceamento de carga
pytest pytest/tests/performance/test_cluster_with_pgpool.py::TestPerformanceCluster::test_cluster_select_only -v -s
```

### Scripts de Automação de Testes

**Testes com Cache Frio (requer sudo):**
```bash
# Baseline com múltiplas execuções
sudo ./scripts/test/run-benchmark-baseline.sh

# Cluster com múltiplas execuções
sudo ./scripts/test/run-benchmark-cluster.sh
```

## 🔧 Scripts Utilitários

```bash
# Criar superusuário
./scripts/create_superuser.sh

# Gerenciar containers
./scripts/container.sh [start|stop|restart|status]
```


## 📊 Estrutura do Projeto

```
postgres-ha-cluster-lab/
├── docker-compose*.yaml          # Arquivos Docker Compose modulares
│   ├── docker-compose.yaml       # Orquestrador principal (usa include)
│   ├── docker-compose.etcd.yaml  # Cluster etcd (3 nós)
│   ├── docker-compose.patroni.yaml # Cluster Patroni/PostgreSQL (3 nós)
│   ├── docker-compose.pgpool.yaml  # PgPool-II
│   └── docker-compose.*_exporter.yaml # Exporters Prometheus
│
├── infra/                        # Infraestrutura como código
│   ├── patroni-postgres/         # Dockerfile e configs Patroni
│   │   ├── Dockerfile
│   │   └── config/patroni.yml
│   └── pgpool/                   # Dockerfile e configs PgPool
│       ├── Dockerfile
│       └── config/
│
├── pytest/                       # Framework de testes
│   ├── src/                      # Código fonte dos testes
│   │   ├── core/                 # Módulos core (managers, config)
│   │   ├── models/               # Modelos de métricas (RTO, RPO, Perf)
│   │   ├── collectors/           # Coletores de métricas
│   │   └── fixtures/             # Fixtures pytest
│   ├── tests/                    # Casos de teste
│   │   ├── resilience/           # Testes RTO e RPO
│   │   └── performance/          # Testes de performance
│   ├── outputs/                  # Resultados (JSONL)
│   └── docs/                     # Documentação dos testes
│
├── scripts/                      # Scripts utilitários
│   ├── health_checks/            # Verificação de saúde do cluster
│   ├── test/                     # Scripts de automação de testes
│   └── lib/                      # Bibliotecas compartilhadas
│
└── docs/                         # Documentação técnica
    ├── code/                     # Documentos de arquitetura
    └── pytest/                   # Documentação de testes
```
## 📚 Documentação

- **[Arquitetura Modular](docs/code/ARQUITETURA-MODULAR.txt)**: Estrutura e organização do código
- **[Guia Docker Compose](docs/code/DOCKER-COMPOSE-GUIDE.md)**: Como usar os arquivos compose
- **[Configuração Patroni](docs/code/CONFIGURACAO-DCS-PATRONI.md)**: Detalhes do DCS e Patroni
- **[Autenticação PgPool](docs/code/AUTENTICACAO-PGPOOL.md)**: Configuração de autenticação
- **[Health Checks PgPool](docs/code/HEALTHCHECK_PGPOOL.md)**: Monitoramento do PgPool
- **[Framework de Testes](pytest/README.md)**: Documentação completa dos testes
- **[Testes Assíncronos RTO](docs/pytest/ASYNC_RTO_TESTING.md)**: Detalhes sobre testes de RTO
- **[Análise de Resultados RPO](docs/pytest/RPO_RESULTS_ANALYSIS.md)**: Como interpretar resultados

## 🎯 Casos de Uso
### 1. Teste de Failover Automático
Simule a falha do nó primário e observe o comportamento do cluster:
```bash
# Identifique o container primário
./scripts/health_checks/patroni.sh

# Encerre o container primário
docker compose stop patroni-postgres-<número-do-primário>

# Observe os secundários assumindo
watch -n 1 'docker compose ps'

# Verifique o novo primário eleito
./scripts/health_checks/patroni.sh
```

### 2. Benchmark de Performance
Compare a performance de um nó único vs. cluster com balanceamento (containers devem estar up):
```bash
# Baseline (nó único)
sudo ./scripts/test/run-benchmark-baseline.sh

# Cluster (com PgPool)
sudo ./scripts/test/run-benchmark-cluster.sh

# Resultados em: pytest/log/
```

### 3. Análise de Resiliência
Meça RTO e RPO do seu cluster:
```bash
# RTO - Tempo de recuperação
./scripts/test/run-crash-up.sh

# RPO - Perda de dados
pytest pytest/tests/resilience/test_rpo_primary_failure.py -v -s

# Resultados em: pytest/outputs/resilience/
```
## 🔍 Monitoramento

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

## 🤝 Contribuindo

Contribuições são bem-vindas! Por favor:
1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📝 Licença

Este projeto está sob a licença especificada no arquivo [LICENSE](LICENSE).

## 👤 Autor

**Eduardo Richard** (richwrd)

## 🔗 Links Úteis

- **Documentação Oficial Patroni**: [patroni.readthedocs.io](https://patroni.readthedocs.io/en/latest/)
- **Documentação Oficial PgPool-II**: [pgpool.net](https://www.pgpool.net/docs/latest/pt/html/index.html)
---

⭐ **Se este projeto foi útil para você, considere dar uma estrela no repositório!**