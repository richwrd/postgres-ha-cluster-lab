#!/bin/bash
# ------------------------------------------------------------------------------------
# Script de testes PGPool
# by: richwrd
# ------------------------------------------------------------------------------------

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Detectar e configurar credenciais de acesso ao PGPool
# ═══════════════════════════════════════════════════════════════════

detect_pgpool_credentials() {
    log_info "Detectando credenciais de acesso ao PGPool..."
    
    # Verificar se as variáveis de ambiente estão definidas
    if [ -z "${TEST_DB_USERNAME}" ] || [ -z "${TEST_DB_PASSWORD}" ]; then
        echo "  ⚠️  Variáveis TEST_DB_USERNAME e/ou TEST_DB_PASSWORD não definidas"
        echo "     └─ Por favor, defina-as no arquivo .env ou nas variáveis de ambiente"
        return 1
    fi
    
    # Testar conexão com as credenciais fornecidas
    local result=$(docker exec -e PGPASSWORD="${TEST_DB_PASSWORD}" "${PGPOOL_CONTAINER}" \
        psql -h localhost -p 5432 -U "${TEST_DB_USERNAME}" -d "${TEST_DB}" -t -A -c \
        "SELECT 1;" 2>/dev/null | tr -d ' \n')
    
    if [ "$result" = "1" ]; then
        echo "  ✅ Credenciais válidas: usuário '${TEST_DB_USERNAME}'"
        return 0
    else
        echo "  ❌ Falha ao autenticar com usuário '${TEST_DB_USERNAME}'"
        echo "     └─ Verifique se o usuário existe e a senha está correta"
        return 1
    fi
}


# ═══════════════════════════════════════════════════════════════════
# ◉➔ TESTES PGPOOL
# ═══════════════════════════════════════════════════════════════════

test_pgpool_container() {
    increment_test
    log_info "Verificando container PGPool..."
    
    if docker ps --filter "name=${PGPOOL_CONTAINER}" --filter "status=running" --format "{{.Names}}" | grep -q "^${PGPOOL_CONTAINER}$"; then
        echo "  ✅ ${PGPOOL_CONTAINER}: Rodando"
        test_passed
        return 0
    else
        echo "  ❌ ${PGPOOL_CONTAINER}: Parado"
        test_failed
        return 1
    fi
}

test_pgpool_connection() {
    increment_test
    log_info "Testando conexão com PGPool..."
    
    # Primeiro verificar se o container está acessível
    if ! docker exec "${PGPOOL_CONTAINER}" true &>/dev/null; then
        echo "  ❌ Container PGPool não acessível"
        test_failed
        return 1
    fi
    
    # Testar conexão via psql
    local version=$(docker exec -e PGPASSWORD="${TEST_DB_PASSWORD}" "${PGPOOL_CONTAINER}" \
        psql -h localhost -p 5432 -U "${TEST_DB_USERNAME}" -d "${TEST_DB}" -t -A -c \
        "SELECT version();" 2>/dev/null | head -1)
    
    if [ -n "${version}" ] && [ "${version}" != "psql: error:" ]; then
        echo "  ✅ Conexão estabelecida com sucesso"
        echo "     └─ ${version:0:60}..."
        test_passed
        return 0
    else
        echo "  ❌ Falha na conexão com PGPool"
        echo "     └─ Verifique se o usuário '${TEST_DB_USERNAME}' existe e tem permissões"
        test_failed
        return 1
    fi
}

test_pgpool_backends() {
    increment_test
    log_info "Verificando backends do PGPool..."
    
    # Obter informações dos backends
    local pool_nodes=$(docker exec -e PGPASSWORD="${TEST_DB_PASSWORD}" "${PGPOOL_CONTAINER}" \
        psql -h localhost -p 5432 -U "${TEST_DB_USERNAME}" -d "${TEST_DB}" -t -c \
        "SHOW POOL_NODES;" 2>/dev/null)
    
    if [ -z "${pool_nodes}" ]; then
        echo "  ❌ Não foi possível obter informações dos backends"
        echo "     └─ Verifique se a conexão com PGPool está OK"
        test_failed
        return 1
    fi
    
    # Contar backends "up" de forma mais robusta
    local backends_count=$(echo "${pool_nodes}" | grep -i "up" | wc -l | tr -d ' ')
    
    # Garantir que é um número válido
    if ! [[ "${backends_count}" =~ ^[0-9]+$ ]]; then
        backends_count=0
    fi
    
    if [ "$backends_count" -gt 0 ]; then
        echo "  ✅ ${backends_count} backend(s) ativo(s) detectado(s)"
        test_passed
        return 0
    else
        echo "  ❌ Nenhum backend ativo detectado"
        echo "     └─ Output de POOL_NODES:"
        echo "${pool_nodes}" | head -5 | sed 's/^/     /'
        test_failed
        return 1
    fi
}

test_pgpool_load_balancing() {
    increment_test
    log_info "Testando Load Balancing..."
    
    # Primeiro verificar se conseguimos executar queries
    local test_query=$(docker exec -e PGPASSWORD="${TEST_DB_PASSWORD}" "${PGPOOL_CONTAINER}" \
        psql -h localhost -p 5432 -U "${TEST_DB_USERNAME}" -d "${TEST_DB}" -t -A -c \
        "SELECT 1;" 2>/dev/null | tr -d ' ')
    
    if [ "${test_query}" != "1" ]; then
        echo "  ❌ Não foi possível executar queries via PGPool"
        echo "     └─ Verifique a conexão com PGPool primeiro"
        test_failed
        return 1
    fi
    
    local -A node_distribution
    local queries=5
    local successful_queries=0
    
    for i in $(seq 1 $queries); do
        local result=$(docker exec -e PGPASSWORD="${TEST_DB_PASSWORD}" "${PGPOOL_CONTAINER}" \
            psql -h localhost -p 5432 -U "${TEST_DB_USERNAME}" -d "${TEST_DB}" -t -A -c \
            "SELECT inet_server_addr()::text || ':' || inet_server_port()::text;" 2>/dev/null | tr -d ' ')
        
        if [ -n "${result}" ] && [ "${result}" != ":" ]; then
            node_distribution["${result}"]=$((${node_distribution["${result}"]} + 1))
            ((successful_queries++))
        fi
    done
    
    local unique_nodes=${#node_distribution[@]}
    
    if [ "$successful_queries" -eq 0 ]; then
        echo "  ❌ Nenhuma query foi executada com sucesso"
        test_failed
        return 1
    fi
    
    if [ "$unique_nodes" -gt 0 ]; then
        echo "  ✅ Load Balancing ativo (${unique_nodes} nó(s) utilizados em ${successful_queries} queries)"
        for node in "${!node_distribution[@]}"; do
            echo "     └─ ${node}: ${node_distribution[$node]} query(s)"
        done
        test_passed
        return 0
    else
        echo "  ❌ Falha no Load Balancing"
        test_failed
        return 1
    fi
}

test_pgpool_write_operations() {
    increment_test
    log_info "Testando operações de escrita via PGPool..."
    
    local test_table="pgpool_health_$(date +%s)"
    local test_value="write-test-$(date +%Y%m%d-%H%M%S)"
    
    # Limpar tabela anterior se existir
    docker exec -e PGPASSWORD="${TEST_DB_PASSWORD}" "${PGPOOL_CONTAINER}" \
        psql -h localhost -p 5432 -U "${TEST_DB_USERNAME}" -d "${TEST_DB}" -c \
        "DROP TABLE IF EXISTS ${test_table};" &>/dev/null
    
    # Criar tabela
    if ! docker exec -e PGPASSWORD="${TEST_DB_PASSWORD}" "${PGPOOL_CONTAINER}" \
        psql -h localhost -p 5432 -U "${TEST_DB_USERNAME}" -d "${TEST_DB}" -c \
        "CREATE TABLE ${test_table} (id serial PRIMARY KEY, data text);" &>/dev/null; then
        echo "  ❌ Falha ao criar tabela de teste"
        echo "     └─ Verifique permissões do usuário '${TEST_DB_USERNAME}'"
        test_failed
        return 1
    fi
    
    # Inserir dados
    if ! docker exec -e PGPASSWORD="${TEST_DB_PASSWORD}" "${PGPOOL_CONTAINER}" \
        psql -h localhost -p 5432 -U "${TEST_DB_USERNAME}" -d "${TEST_DB}" -c \
        "INSERT INTO ${test_table} (data) VALUES ('${test_value}');" &>/dev/null; then
        echo "  ❌ Falha ao inserir dados"
        # Tentar limpar
        docker exec -e PGPASSWORD="${TEST_DB_PASSWORD}" "${PGPOOL_CONTAINER}" \
            psql -h localhost -p 5432 -U "${TEST_DB_USERNAME}" -d "${TEST_DB}" -c \
            "DROP TABLE IF EXISTS ${test_table};" &>/dev/null
        test_failed
        return 1
    fi
    
    # Verificar dados
    local result=$(docker exec -e PGPASSWORD="${TEST_DB_PASSWORD}" "${PGPOOL_CONTAINER}" \
        psql -h localhost -p 5432 -U "${TEST_DB_USERNAME}" -d "${TEST_DB}" -t -A -c \
        "SELECT data FROM ${test_table} LIMIT 1;" 2>/dev/null | tr -d ' ')
    
    # Limpar tabela
    docker exec -e PGPASSWORD="${TEST_DB_PASSWORD}" "${PGPOOL_CONTAINER}" \
        psql -h localhost -p 5432 -U "${TEST_DB_USERNAME}" -d "${TEST_DB}" -c \
        "DROP TABLE IF EXISTS ${test_table};" &>/dev/null
    
    if [ "$result" = "$test_value" ]; then
        echo "  ✅ Operações de escrita: OK"
        echo "     └─ CREATE TABLE, INSERT e SELECT funcionando"
        test_passed
        return 0
    else
        echo "  ❌ Falha nas operações de escrita"
        echo "     └─ Esperado: ${test_value}"
        echo "     └─ Obtido: ${result:-<vazio>}"
        test_failed
        return 1
    fi
}
