#!/bin/sh
# ------------------------------------------------------------------------------------
# BIBLIOTECA COMUM: logging.sh
# Propósito: Fornece funções padronizadas para logging em todos os scripts de failover
# Princípio DRY: Centraliza a lógica de logging para evitar duplicação
# ------------------------------------------------------------------------------------

# --- Função Principal de Log ---
log_metric() {
    local message="$1"
    local timestamp=$(date --iso-8601=seconds)
    local script_name=$(basename "$0")
    
    echo "${timestamp} [${script_name}] ${message}" | tee -a "${LOG_FILE_FAILOVER}"
}

# --- Funções Especializadas ---
log_start() {
    local process_name="$1"
    log_metric "--- INÍCIO DO ${process_name} ---"
}

log_end() {
    local process_name="$1"
    local start_time="$2"
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
    
    log_metric "--- FIM DO ${process_name} --- (Duração: ${duration} segundos)"
}

log_error() {
    local message="$1"
    log_metric "ERRO: ${message}"
}

log_success() {
    local message="$1"
    log_metric "SUCESSO: ${message}"
}

log_warning() {
    local message="$1"
    log_metric "AVISO: ${message}"
}

log_critical() {
    local message="$1"
    log_metric "FALHA CRÍTICA: ${message}"
}

# --- Função para Inicializar Timing ---
get_timestamp() {
    date +%s.%N
}
