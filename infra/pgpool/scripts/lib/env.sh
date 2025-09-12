#!/bin/sh
# ------------------------------------------------------------------------------------
# CONFIGURAÇÃO CENTRALIZADA: env.sh
# Propósito: Define e exporta todas as variáveis de ambiente utilizadas pelos scripts
# Este arquivo serve como um único ponto de verdade para toda a configuração
# ------------------------------------------------------------------------------------

# --- Configurações de Diretórios ---
export LIB_DIR="${LIB_DIR:-/opt/pgpool/bin/scripts/lib}"

# --- Configurações de Logging ---
export LOG_FILE_FAILOVER="${LOG_FILE_FAILOVER:-/var/log/pgpool/failover_metrics.log}"

# --- Configurações do Pgpool-II PCP (Pgpool Control Protocol) ---
export PCP_USER="${PGPOOL_PCP_USER:-pcp_admin}"
export PCP_HOST="${PCP_HOST:-localhost}"
export PCP_PORT="${PCP_PORT:-9898}"

# --- Configurações do Patroni ---
# Lista de endpoints da API do Patroni (separados por espaço)
# Exemplo: "http://patroni-1:8008 http://patroni-2:8008 http://patroni-3:8008"
export PATRONI_API_ENDPOINTS="${PATRONI_API_ENDPOINTS:-http://patroni-postgres-1:8008 http://patroni-postgres-2:8008 http://patroni-postgres-3:8008}"

# --- Configurações de Timeout ---
export CURL_TIMEOUT="${CURL_TIMEOUT:-3}"
export API_RETRY_COUNT="${API_RETRY_COUNT:-3}"

# --- Configurações de Debug ---
export DEBUG_MODE="${DEBUG_MODE:-false}"

# --- Validações ---
validate_environment() {
    local errors=0
    
    # Verificar se variáveis críticas estão definidas
    if [ -z "$PATRONI_API_ENDPOINTS" ]; then
        echo "ERRO: PATRONI_API_ENDPOINTS não está definido" >&2
        errors=$((errors + 1))
    fi
    
    if [ -z "$PCP_USER" ]; then
        echo "ERRO: PCP_USER não está definido" >&2
        errors=$((errors + 1))
    fi
    
    # Verificar se o diretório de log existe
    if [ ! -d "$(dirname "$LOG_FILE_FAILOVER")" ]; then
        echo "AVISO: Diretório de log $(dirname "$LOG_FILE_FAILOVER") não existe, tentando criar..." >&2
        mkdir -p "$(dirname "$LOG_FILE_FAILOVER")" 2>/dev/null || {
            echo "ERRO: Não foi possível criar diretório de log $(dirname "$LOG_FILE_FAILOVER")" >&2
            errors=$((errors + 1))
        }
    fi
    
    if [ $errors -gt 0 ]; then
        echo "ERRO: $errors erro(s) de configuração encontrado(s). Verifique as variáveis de ambiente." >&2
        return 1
    fi
    
    return 0
}

# --- Debug Information ---
print_environment() {
    if [ "$DEBUG_MODE" = "true" ]; then
        echo "=== CONFIGURAÇÃO DE AMBIENTE ===" >&2
        echo "LIB_DIR: $LIB_DIR" >&2
        echo "LOG_FILE_FAILOVER: $LOG_FILE_FAILOVER" >&2
        echo "PCP_USER: $PCP_USER" >&2
        echo "PCP_HOST: $PCP_HOST" >&2
        echo "PCP_PORT: $PCP_PORT" >&2
        echo "PATRONI_API_ENDPOINTS: $PATRONI_API_ENDPOINTS" >&2
        echo "CURL_TIMEOUT: $CURL_TIMEOUT" >&2
        echo "API_RETRY_COUNT: $API_RETRY_COUNT" >&2
        echo "===============================" >&2
    fi
}

# --- Executar validações automaticamente quando o arquivo for sourced ---
if ! validate_environment; then
    echo "FALHA CRÍTICA: Configuração de ambiente inválida" >&2
    return 1 2>/dev/null || exit 1
fi

# Mostrar informações de debug se habilitado
print_environment
