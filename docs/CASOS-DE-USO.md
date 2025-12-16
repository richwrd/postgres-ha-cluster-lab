# Casos de Uso

Exemplos práticos de como utilizar o cluster PostgreSQL de Alta Disponibilidade em diferentes cenários.

## 1. Teste de Failover Automático

Simule a falha do nó primário e observe o comportamento do cluster durante a recuperação automática.

### Passo a Passo

**1. Identifique o container primário:**

```bash
./scripts/health_checks/patroni.sh
```

A saída mostrará qual nó está como `Leader` (primário).

**2. Simule a falha encerrando o container primário:**

```bash
# Substitua <número-do-primário> pelo número identificado (1, 2 ou 3)
docker compose stop patroni-postgres-<número-do-primário>
```

**3. Observe o processo de failover:**

```bash
# Monitore em tempo real
watch -n 1 'docker compose ps'

# Ou verifique os logs
docker compose logs -f patroni-postgres-2 patroni-postgres-3
```

**4. Verifique o novo primário eleito:**

```bash
./scripts/health_checks/patroni.sh
```

**5. Restaure o nó que falhou:**

```bash
docker compose start patroni-postgres-<número-do-primário>
```

O nó voltará como réplica e sincronizará automaticamente.

### Resultados Esperados

- ⏱️ **Tempo de detecção**: ~10-15 segundos
- 🔄 **Tempo de eleição**: ~5-10 segundos
- ✅ **Disponibilidade**: Conexões são redirecionadas automaticamente
- 📊 **Perda de dados**: Mínima (RPO < 1 segundo em condições normais)

---

## 2. Benchmark de Performance

Compare a performance entre um nó único PostgreSQL e o cluster com balanceamento de carga.

### Baseline (Nó Único)

```bash
# Certifique-se de que apenas o ambiente de baseline está up
cd pytest/docker
docker compose -f docker-compose.pgbench-baseline.yaml up -d

# Execute o benchmark
sudo ../scripts/test/run-benchmark-baseline.sh
```

### Cluster com PgPool

```bash
# Suba o cluster completo
cd ../../
docker compose up -d

# Execute o benchmark
sudo ./scripts/test/run-benchmark-cluster.sh
```

### Análise dos Resultados

Os resultados são salvos em `pytest/outputs/performance/`:

- **TPS** (Transações por Segundo): Vazão do sistema
- **Latência Média**: Tempo de resposta médio
- **Latência P95/P99**: Percentis de latência

_Em breve será disponibilizado um guia completo de análise comparativa com gráficos._

---

## 3. Análise de Resiliência (RTO/RPO)

Meça as características de resiliência do cluster.

### Recovery Time Objective (RTO)

Tempo necessário para o cluster se recuperar de uma falha.

```bash
# Teste de falha abrupta do primário
./scripts/test/run-crash-up.sh

# Os resultados incluem:
# - Tempo de detecção da falha
# - Tempo de eleição do novo líder
# - Tempo de recuperação do cluster
# - Tempo total de indisponibilidade
```

### Recovery Point Objective (RPO)

Quantidade de dados que pode ser perdida durante uma falha.

```bash
cd pytest
pytest tests/resilience/test_rpo_primary_failure.py -v -s

# O teste:
# 1. Inicia escrita contínua de transações
# 2. Simula falha do primário
# 3. Conta quantas transações foram perdidas
# 4. Calcula o RPO
```

**Resultados:** Salvos em `pytest/outputs/resilience/`

---

## 4. Balanceamento de Carga de Leituras

Demonstre como o PgPool distribui consultas SELECT entre as réplicas.

### Configuração

O PgPool está configurado para:

- Enviar `SELECT` para réplicas (load balancing)
- Enviar `INSERT/UPDATE/DELETE` para o primário
- Failover automático em caso de falha

### Teste Manual

```bash
# Conecte ao PgPool
psql -h localhost -p 5432 -U postgres -d postgres

# Execute várias consultas SELECT
SELECT pg_is_in_recovery(), inet_server_addr();
SELECT pg_is_in_recovery(), inet_server_addr();
SELECT pg_is_in_recovery(), inet_server_addr();
```

Observe que as consultas são distribuídas entre diferentes nós (IPs diferentes).

### Monitoramento

```bash
# Verifique as estatísticas do PgPool
docker compose exec pgpool psql -h localhost -p 9999 -U postgres -c "SHOW POOL_NODES;"

# Veja as conexões ativas
docker compose exec pgpool psql -h localhost -p 9999 -U postgres -c "SHOW POOL_PROCESSES;"
```

---

## 5. Switchover Planejado

Realize uma troca planejada de líder sem indisponibilidade.

```bash
# 1. Identifique o líder atual
./scripts/health_checks/patroni.sh

# 2. Force um switchover para outro nó
docker compose exec patroni-postgres-1 patronictl switchover --force

# 3. Escolha o novo líder quando solicitado
# Exemplo: patroni-postgres-2

# 4. Verifique o novo líder
./scripts/health_checks/patroni.sh
```

### Casos de Uso

- **Manutenção programada** do servidor primário
- **Balanceamento de carga** entre servidores físicos
- **Testes de DR** (Disaster Recovery)

---

## 6. Teste de Replicação

Verifique que os dados estão sendo replicados corretamente.

```bash
# 1. Conecte ao primário e insira dados
psql -h localhost -p 5432 -U postgres -d postgres -c "
CREATE TABLE IF NOT EXISTS test_replication (
    id SERIAL PRIMARY KEY,
    data TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO test_replication (data)
VALUES ('Test 1'), ('Test 2'), ('Test 3');
"

# 2. Conecte a uma réplica e verifique os dados
# Primeiro identifique uma réplica
./scripts/health_checks/patroni.sh

# Conecte diretamente à réplica (substitua X pelo número da réplica)
docker compose exec patroni-postgres-X psql -U postgres -d postgres -c "
SELECT * FROM test_replication;
"

# 3. Verifique o lag de replicação
docker compose exec patroni-postgres-1 psql -U postgres -d postgres -c "
SELECT
    client_addr,
    state,
    sync_state,
    pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS lag_bytes
FROM pg_stat_replication;
"
```

---

## 7. Recuperação de Nó Degradado

Simule e recupere um nó que ficou desatualizado.

```bash
# 1. Pause um nó secundário
docker compose pause patroni-postgres-3

# 2. Faça alterações no primário
psql -h localhost -p 5432 -U postgres -d postgres -c "
INSERT INTO test_replication (data)
SELECT 'Data ' || generate_series(1, 10000);
"

# 3. Despause o nó
docker compose unpause patroni-postgres-3

# 4. Observe a sincronização
docker compose logs -f patroni-postgres-3

# 5. Verifique que está sincronizado
./scripts/health_checks/patroni.sh
```

---

## 8. Monitoramento com Prometheus Exporters

_Em breve será disponibilizado um guia completo de configuração e uso dos exporters Prometheus._

### Métricas Disponíveis

- **PostgreSQL Exporter**: Métricas de banco de dados
- **Patroni API**: Status do cluster
- **PgPool Exporter**: Estatísticas de conexões
- **Etcd Metrics**: Saúde do DCS

---

## Troubleshooting Comum

### Cluster não elege líder

```bash
# Verifique o etcd
./scripts/health_checks/etcd.sh

# Verifique os logs do Patroni
docker compose logs patroni-postgres-1 patroni-postgres-2 patroni-postgres-3
```

### PgPool não conecta ao backend

```bash
# Verifique o status dos nodes
docker compose exec pgpool psql -h localhost -p 9999 -U postgres -c "SHOW POOL_NODES;"

# Verifique logs do PgPool
docker compose logs pgpool
```

### Replicação atrasada

```bash
# Verifique o lag em cada réplica
docker compose exec patroni-postgres-1 psql -U postgres -c "
SELECT * FROM pg_stat_replication;
"
```

---

## Próximos Passos

- Explore os [testes automatizados](TESTES.md) para validação contínua
- Consulte a [documentação técnica](stack/) para configurações avançadas
- Revise o [Quick Start](QUICK-START.md) para configuração inicial
