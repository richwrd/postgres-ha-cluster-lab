#!/bin/bash

# ═══════════════════════════════════════════════════════════════════
# Script de Teste do PGPool-2
# by: richwrd
# ═══════════════════════════════════════════════════════════════════

# ◉➔ Determinar diretórios e carregar bibliotecas
# ═══════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

# Carregar biblioteca de environment
if [ -f "${LIB_DIR}/env.sh" ]; then
    source "${LIB_DIR}/env.sh"
    load_env
else
    echo "ERRO: Biblioteca env.sh não encontrada em ${LIB_DIR}/env.sh"
    exit 1
fi

# Carregar biblioteca de logging
if [ -f "${LIB_DIR}/logging.sh" ]; then
    source "${LIB_DIR}/logging.sh"
else
    echo "ERRO: Biblioteca de logging não encontrada em ${LIB_DIR}/logging.sh"
    exit 1
fi

# ◉➔ Configurações Iniciais
# ═══════════════════════════════════════════════════════════════════

# Usuário e senha do PostgreSQL para os testes (usuário postgres não permite conexao via pgpool)
PGUSER="healthchecker"
PGPASSWORD="jVj7VvWhSiz22hBRt5kF87NS02"

# Porta do PGPool (usar variável do .env)
PGPOOL_PORT="${PGPOOL_HOST_PORT:-5432}"

# Nome do container PGPool (usar variável do .env)
PGPOOL_CONTAINER="${PGPOOL_NAME:-pgpool}"

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Testes
# ═══════════════════════════════════════════════════════════════════

test_container_running() {
    log_info "Verificando se o container PGPool está rodando..."
    
    if docker ps --format '{{.Names}}' | grep -q "^${PGPOOL_CONTAINER}$"; then
        log_success "Container ${PGPOOL_CONTAINER} está rodando"
        return 0
    else
        log_error "Container ${PGPOOL_CONTAINER} não está rodando"
        return 1
    fi
}

test_env_file() {
    log_info "Verificando arquivo de environment do PGPool..."
    
    if [ -f "${ENV_PGPOOL}" ]; then
        log_success "Arquivo ${ENV_PGPOOL} encontrado"
        return 0
    else
        log_warning "Arquivo ${ENV_PGPOOL} não encontrado"
        return 1
    fi
}

test_pgpool_connection() {
    log_info "Testando conexão com PGPool na porta ${PGPOOL_PORT}..."
    
    PGPASSWORD="${PGPASSWORD}" psql -h localhost -p "${PGPOOL_PORT}" -U "${PGUSER}" -d postgres -c "SELECT version();" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        log_success "Conexão com PGPool estabelecida com sucesso"
        return 0
    else
        log_error "Falha ao conectar com PGPool"
        return 1
    fi
}

test_show_pool_nodes() {
    log_info "Obtendo informações dos nodes do pool..."
    
    PGPASSWORD="${PGPASSWORD}" psql -h localhost -p "${PGPOOL_PORT}" -U "${PGUSER}" -d postgres -c "SHOW POOL_NODES;"
    
    if [ $? -eq 0 ]; then
        log_success "Informações dos nodes obtidas com sucesso"
        return 0
    else
        log_error "Falha ao obter informações dos nodes"
        return 1
    fi
}

test_show_pool_status() {
    log_info "Obtendo status do pool..."
    
    PGPASSWORD="${PGPASSWORD}" psql -h localhost -p "${PGPOOL_PORT}" -U "${PGUSER}" -d postgres -c "SHOW POOL_STATUS;"
    
    if [ $? -eq 0 ]; then
        log_success "Status do pool obtido com sucesso"
        return 0
    else
        log_error "Falha ao obter status do pool"
        return 1
    fi
}

test_simple_query() {
    log_info "Executando query simples de teste..."
    
    PGPASSWORD="${PGPASSWORD}" psql -h localhost -p "${PGPOOL_PORT}" -U "${PGUSER}" -d postgres -c "SELECT current_timestamp, inet_server_addr(), inet_server_port();"
    
    if [ $? -eq 0 ]; then
        log_success "Query executada com sucesso"
        return 0
    else
        log_error "Falha ao executar query"
        return 1
    fi
}

test_container_logs() {
    log_info "Exibindo últimas linhas do log do container..."
    
    docker logs --tail 20 "${PGPOOL_CONTAINER}"
    
    if [ $? -eq 0 ]; then
        log_success "Logs obtidos com sucesso"
        return 0
    else
        log_error "Falha ao obter logs"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Execução Principal
# ═══════════════════════════════════════════════════════════════════

main() {
    # Iniciar timing
    START_TIME=$(get_timestamp)
    
    log_start "TESTE DO PGPOOL"
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  TESTE DO PGPOOL"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo "Configurações:"
    echo "  - Usuário: ${PGUSER}"
    echo "  - Porta: ${PGPOOL_PORT}"
    echo "  - Container: ${PGPOOL_CONTAINER}"
    echo "  - Project Root: ${PROJECT_ROOT}"
    echo "  - Env Root: ${ENV_ROOT}"
    echo "  - Env PGPool: ${ENV_PGPOOL}"
    echo "  - Log File: ${LOG_FILE}"
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    
    # Contador de testes
    PASSED=0
    FAILED=0
    
    # Executar testes
    test_container_running && ((PASSED++)) || ((FAILED++))
    echo ""
    
    test_env_file && ((PASSED++)) || ((FAILED++))
    echo ""
    
    test_pgpool_connection && ((PASSED++)) || ((FAILED++))
    echo ""
    
    test_show_pool_nodes && ((PASSED++)) || ((FAILED++))
    echo ""
    
    test_show_pool_status && ((PASSED++)) || ((FAILED++))
    echo ""
    
    test_simple_query && ((PASSED++)) || ((FAILED++))
    echo ""
    
    test_container_logs && ((PASSED++)) || ((FAILED++))
    echo ""
    
    # Resumo
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  RESUMO DOS TESTES"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    log_success "Testes passaram: ${PASSED}"
    log_error "Testes falharam: ${FAILED}"
    echo ""
    
    if [ ${FAILED} -eq 0 ]; then
        log_success "Todos os testes passaram! ✓"
        log_end "TESTE DO PGPOOL" "${START_TIME}"
        exit 0
    else
        log_critical "Alguns testes falharam! ✗"
        log_end "TESTE DO PGPOOL" "${START_TIME}"
        exit 1
    fi
}

# Executar script principal
main
