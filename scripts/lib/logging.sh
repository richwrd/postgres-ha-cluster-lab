#!/bin/bash
# ------------------------------------------------------------------------------------
# BIBLIOTECA COMUM: logging.sh
# Fornece funções padronizadas para logging em todos os scripts de teste
# by: richwrd
# ------------------------------------------------------------------------------------

# --- Cores para output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- Função Principal de Log ---
log_metric() {
    local message="$1"
    local timestamp=$(date --iso-8601=seconds)
    local script_name=$(basename "$0")
    
    # Se LOG_FILE estiver definido, registra no arquivo; caso contrário, não imprime nada
    if [ -n "${LOG_FILE}" ]; then
        printf '%s [%s] %s\n' "$timestamp" "$script_name" "$message" >> "${LOG_FILE}" 2>/dev/null
    fi
}

# --- Funções Especializadas ---
log_start() {
    local process_name="$1"
    echo -e "${CYAN}[START]${NC} --- INÍCIO DO ${process_name} ---"
    log_metric "--- INÍCIO DO ${process_name} ---"
}

log_end() {
    local process_name="$1"
    local start_time="$2"
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
    
    echo -e "${CYAN}[END]${NC} --- FIM DO ${process_name} --- (Duração: ${duration} segundos)"
    log_metric "--- FIM DO ${process_name} --- (Duração: ${duration} segundos)"
}

log_error() {
    local message="$1"
    echo -e "${RED}[ERROR]${NC} ${message}"
    log_metric "ERRO: ${message}"
}


log_info() {
    local message="$1"
    echo -e "${BLUE}[INFO]${NC} ${message}"
    log_metric "INFO: ${message}"
}

log_success() {
    local message="$1"
    echo -e "${GREEN}[SUCCESS]${NC} ${message}"
    log_metric "SUCESSO: ${message}"
}

log_warning() {
    local message="$1"
    echo -e "${YELLOW}[WARNING]${NC} ${message}"
    log_metric "AVISO: ${message}"
}

log_critical() {
    local message="$1"
    echo -e "${RED}[CRITICAL]${NC} ${message}"
    log_metric "FALHA CRÍTICA: ${message}"
}

# --- Função para Inicializar Timing ---
get_timestamp() {
    date +%s.%N
}
