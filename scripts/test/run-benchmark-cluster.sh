#!/bin/bash

# ==============================================================================
# SCRIPT DE COLETA DE DADOS DE PERFORMANCE (MÉTODO CACHE FRIO)
#
# Este script DEVE ser executado como root (sudo) para poder limpar o cache
# de disco do sistema operacional (drop_caches).
# ==============================================================================

# --- IMPORTAR BIBLIOTECAS ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/env.sh"
source "${SCRIPT_DIR}/../lib/logging.sh"

# Carregar variáveis de ambiente
load_env

# Definir variáveis necessárias para test_pgpool_connection
PGPOOL_CONTAINER="${PGPOOL_NAME}"
TEST_DB="postgres"

# Carregar módulo de testes do PGPool
source "${SCRIPT_DIR}/../health_checks/pgpool.sh"

# Contadores de testes (necessários para as funções de teste)
declare TOTAL_TESTS=0
declare PASSED_TESTS=0
declare FAILED_TESTS=0

increment_test() {
    ((TOTAL_TESTS++))
}

test_passed() {
    ((PASSED_TESTS++))
}

test_failed() {
    ((FAILED_TESTS++))
}

# --- VERIFICAÇÃO DE ROOT ---
if [ "$EUID" -ne 0 ]; then
  echo "ERRO: Este script deve ser executado como root (sudo)."
  echo "      (Necessário para 'sync; echo 3 > /proc/sys/vm/drop_caches')"
  exit 1
fi

# --- 1. CONFIGURAÇÃO (AJUSTE CONFORME O TESTE) ---

# Defina os clientes a serem testados (Outer loop)
CLIENT_COUNTS=(10 25 50 75 100 125 150 200)

# Número de execuções por cliente (Inner loop)
NUM_RUNS=3

# Crie um diretório para salvar os logs (ex: "cluster_select_only")
LOG_DIR="./pytest/log/cluster_select_only_results"

# Caminho do docker-compose (relativo à pasta pytest/scripts)
DOCKER_COMPOSE_PATH="./docker-compose.yaml"

# Nome do serviço Docker a ser reiniciado
DOCKER_SERVICE_NAME="patroni-postgres-1 patroni-postgres-2 patroni-postgres-3 pgpool"

# --- AJUSTE ESTES DOIS BLOCOS PARA CADA CENÁRIO ---

# Cenário: Cluster (Nó Principal)
TEST_PY_FILE="./pytest/tests/performance/test_cluster_with_pgpool.py"
TEST_FUNCTION_PATH="TestPerformanceCluster::test_cluster_select_only"

# ------------------------------------------------------------------------------

# --- FUNÇÃO AUXILIAR: AGUARDAR PGPOOL FICAR PRONTO ---

wait_for_pgpool_ready() {
    local max_attempts=30
    local attempt=1
    local wait_seconds=2
    
    echo "      Aguardando PGPool ficar pronto..."
    
    while [ $attempt -le $max_attempts ]; do
        # Verificar se o container está rodando
        if ! docker ps --filter "name=${PGPOOL_CONTAINER}" --filter "status=running" --format "{{.Names}}" | grep -q "^${PGPOOL_CONTAINER}$"; then
            echo "      └─ Tentativa $attempt/$max_attempts: Container não está rodando"
            sleep $wait_seconds
            ((attempt++))
            continue
        fi
        
        # Tentar conectar ao PGPool
        local result=$(docker exec -e PGPASSWORD="${TEST_DB_PASSWORD}" "${PGPOOL_CONTAINER}" \
            psql -h localhost -p 5432 -U "${TEST_DB_USERNAME}" -d "${TEST_DB}" -t -A -c \
            "SELECT 1;" 2>/dev/null | tr -d ' \n')
        
        if [ "$result" = "1" ]; then
            echo "      └─ ✅ PGPool está pronto! (tentativa $attempt/$max_attempts)"
            return 0
        fi
        
        echo "      └─ Tentativa $attempt/$max_attempts: PGPool ainda não está pronto"
        sleep $wait_seconds
        ((attempt++))
    done
    
    echo "      └─ ❌ Timeout: PGPool não ficou pronto após ${max_attempts} tentativas"
    return 1
}

# --- 2. LÓGICA DE EXECUÇÃO ---

mkdir -p $LOG_DIR
echo "Bateria de testes iniciada. Logs serão salvos em: $LOG_DIR"
echo "Docker Compose: $DOCKER_COMPOSE_PATH"
echo "Serviço a ser reiniciado: $DOCKER_SERVICE_NAME"
echo "Clientes: ${CLIENT_COUNTS[@]}"
echo "Execuções por cliente: $NUM_RUNS"
echo "-----------------------------------------------------"
echo ""

# Loop Externo: Itera sobre a contagem de clientes
for client_count in "${CLIENT_COUNTS[@]}"; do
  echo ""
  echo "=== INICIANDO TESTES PARA $client_count CLIENTES ==="

  # Loop Interno: Itera sobre o número de execuções (NUM_RUNS)
  for i in $(seq 1 $NUM_RUNS); do
    echo "  [RUN $i/$NUM_RUNS] - $client_count clientes"
    LOG_FILE="$LOG_DIR/${client_count}_clients_run_${i}.log"

    # 1. PARAR O SERVIÇO
    echo "      1/5: Parando serviço: $DOCKER_SERVICE_NAME"
    docker compose -f $DOCKER_COMPOSE_PATH stop $DOCKER_SERVICE_NAME > /dev/null

    # 2. LIMPAR O CACHE DE DISCO DO S.O. (O PASSO CRÍTICO)
    echo "      2/5: Limpando cache de disco do S.O. (drop_caches)"
    sync
    echo 3 > /proc/sys/vm/drop_caches

    # 3. INICIAR O SERVIÇO
    echo "      3/5: Iniciando serviço: $DOCKER_SERVICE_NAME"
    docker compose -f $DOCKER_COMPOSE_PATH up -d $DOCKER_SERVICE_NAME > /dev/null

    # 4. AGUARDAR PGPOOL FICAR PRONTO
    if ! wait_for_pgpool_ready; then
      echo "  ❌ ERRO: PGPool não ficou pronto a tempo. Pulando esta execução."
      echo "     └─ Verifique os logs: docker compose -f $DOCKER_COMPOSE_PATH logs pgpool"
      continue
    fi

    # 5. EXECUTAR O TESTE PYTEST E SALVAR LOG
    TEST_TARGET="${TEST_PY_FILE}::${TEST_FUNCTION_PATH}[${client_count}]"
    echo "      5/5: Executando pytest: $TEST_TARGET"
    
    # Executa o pytest e redireciona stdout e stderr para o arquivo de log
    source ./pytest/.venv/bin/activate; pytest "$TEST_TARGET" -v -s > $LOG_FILE 2>&1

    echo "  [RUN $i/$NUM_RUNS] Concluída. Log: $LOG_FILE"
    echo "-----------------------------------------------------"
  done
  
  echo "=== TESTES PARA $client_count CLIENTES CONCLUÍDOS ==="
done

echo ""
echo "BATERIA DE TESTES COMPLETA. Todos os resultados estão em: $LOG_DIR"