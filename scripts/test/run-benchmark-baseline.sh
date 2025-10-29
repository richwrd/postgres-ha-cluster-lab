#!/bin/bash

# ==============================================================================
# SCRIPT DE COLETA DE DADOS DE PERFORMANCE (MÉTODO CACHE FRIO)
#
# Este script DEVE ser executado como root (sudo) para poder limpar o cache
# de disco do sistema operacional (drop_caches).
# ==============================================================================

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

# Tempo de espera para o PostgreSQL iniciar (em segundos)
WAIT_TIME=20

# Crie um diretório para salvar os logs (ex: "baseline_select_only")
LOG_DIR="../../pytest/log/baseline_select_only_results"

# Caminho do docker-compose (relativo à pasta pytest)
DOCKER_COMPOSE_PATH="../../pytest/docker/docker-compose.baseline.yaml"

# --- AJUSTE ESTES DOIS BLOCOS PARA CADA CENÁRIO ---

# Cenário: Baseline (Nó Único)
TEST_PY_FILE="../../pytest/tests/performance/test_baseline_single_node.py"
TEST_FUNCTION_PATH="TestPerformanceBaseline::test_baseline_select_only"

# ------------------------------------------------------------------------------

# --- 2. LÓGICA DE EXECUÇÃO ---

mkdir -p $LOG_DIR
echo "Bateria de testes iniciada. Logs serão salvos em: $LOG_DIR"
echo "Docker Compose: $DOCKER_COMPOSE_PATH"
echo "Clientes: ${CLIENT_COUNTS[@]}"
echo "Execuções por cliente: $NUM_RUNS"
echo "Tempo de espera: $WAIT_TIME segundos"
echo "-----------------------------------------------------"

# Loop Externo: Itera sobre a contagem de clientes
for client_count in "${CLIENT_COUNTS[@]}"; do
  echo ""
  echo "=== INICIANDO TESTES PARA $client_count CLIENTES ==="

  # Loop Interno: Itera sobre o número de execuções (NUM_RUNS)
  for i in $(seq 1 $NUM_RUNS); do
    echo "  [RUN $i/$NUM_RUNS] - $client_count clientes"
    LOG_FILE="$LOG_DIR/${client_count}_clients_run_${i}.log"

    # 1. PARAR O(S) CONTÊINER(ES)
    echo "      1/5: Parando serviços"
    docker compose -f $DOCKER_COMPOSE_PATH stop > /dev/null

    # 2. LIMPAR O CACHE DE DISCO DO S.O. (O PASSO CRÍTICO)
    echo "      2/5: Limpando cache de disco do S.O. (drop_caches)"
    sync
    echo 3 > /proc/sys/vm/drop_caches

    # 3. INICIAR O(S) CONTÊINER(ES)
    echo "      3/5: Iniciando serviços"
    docker compose -f $DOCKER_COMPOSE_PATH up -d > /dev/null

    # 4. AGUARDAR O BOOT
    echo "      4/5: Aguardando $WAIT_TIME segundos para o boot..."
    sleep $WAIT_TIME

    # 5. EXECUTAR O TESTE PYTEST E SALVAR LOG
    TEST_TARGET="${TEST_PY_FILE}::${TEST_FUNCTION_PATH}[${client_count}]"
    echo "      5/5: Executando pytest: $TEST_TARGET"
    
    # Executa o pytest e redireciona stdout e stderr para o arquivo de log
    source ../../pytest/.venv/bin/activate; pytest "$TEST_TARGET" -v -s > $LOG_FILE 2>&1

    echo "  [RUN $i/$NUM_RUNS] Concluída. Log: $LOG_FILE"
    echo "-----------------------------------------------------"
  done
  
  echo "=== TESTES PARA $client_count CLIENTES CONCLUÍDOS ==="
done

echo ""
echo "BATERIA DE TESTES COMPLETA. Todos os resultados estão em: $LOG_DIR"