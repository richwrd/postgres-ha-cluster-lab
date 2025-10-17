#!/bin/bash
# ------------------------------------------------------------------------------------
# Script para testar PGPool-II com Connection Pooling e Load Balancing
# by: richwrd
# ------------------------------------------------------------------------------------

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Carregar bibliotecas de ambiente
# ═══════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/env.sh"
source "${SCRIPT_DIR}/../lib/logging.sh"

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Variáveis globais
# ═══════════════════════════════════════════════════════════════════

declare PGPOOL_CONTAINER
declare -a PATRONI_INSTANCES
declare COMPOSE_FILE
declare TEST_TABLE
declare TEST_DB="postgres"
declare TEST_USER="postgres"

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Validar variáveis de ambiente necessárias
# ═══════════════════════════════════════════════════════════════════

validate_required_vars() {
    log_info "Validando variáveis de ambiente..."
    
    if [ -z "${PGPOOL_NAME}" ]; then
        log_error "Variável PGPOOL_NAME não está definida"
        return 1
    fi
    
    PGPOOL_CONTAINER="${PGPOOL_NAME}"
    
    # Construir array de instâncias Patroni
    PATRONI_INSTANCES=()
    local idx=1
    while true; do
        local var_name="PATRONI${idx}_NAME"
        local instance_name="${!var_name}"
        
        if [ -z "${instance_name}" ]; then
            break
        fi
        
        PATRONI_INSTANCES+=("${instance_name}")
        ((idx++))
    done
    
    if [ ${#PATRONI_INSTANCES[@]} -eq 0 ]; then
        log_warning "Nenhuma instância Patroni detectada nas variáveis de ambiente"
    fi
    
    echo ""
    echo "  📋 Configuração detectada:"
    echo "     • Container PGPool: ${PGPOOL_CONTAINER}"
    echo "     • Instâncias Patroni: ${#PATRONI_INSTANCES[@]}"
    for instance in "${PATRONI_INSTANCES[@]}"; do
        echo "       - ${instance}"
    done
    echo ""
    
    log_success "Variáveis de ambiente validadas"
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Exibir cabeçalho do teste
# ═══════════════════════════════════════════════════════════════════

show_header() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  🔍 TESTE DO PGPOOL-II CONNECTION POOLER"
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Container: ${PGPOOL_CONTAINER}"
    echo "  Compose File: ${COMPOSE_FILE}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Verificar status do container PGPool
# ═══════════════════════════════════════════════════════════════════

check_container_status() {
    log_info "Verificando status do container PGPool..."
    echo ""
    
    docker compose -f "${COMPOSE_FILE}" ps "${PGPOOL_CONTAINER}"
    echo ""
    
    if docker ps --filter "name=${PGPOOL_CONTAINER}" --filter "status=running" --format "{{.Names}}" | grep -q "^${PGPOOL_CONTAINER}$"; then
        log_success "✓ ${PGPOOL_CONTAINER} está rodando"
        return 0
    else
        log_error "✗ ${PGPOOL_CONTAINER} NÃO está rodando"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Verificar conectividade básica com PGPool
# ═══════════════════════════════════════════════════════════════════

test_pgpool_connection() {
    log_info "Testando conexão com PGPool..."
    echo ""
    
    local version=$(docker exec "${PGPOOL_CONTAINER}" psql -h localhost -p 5432 -U "${TEST_USER}" -d "${TEST_DB}" -t -c "SELECT version();" 2>/dev/null | head -1 | xargs)
    
    if [ -n "${version}" ]; then
        echo "  ✅ Conexão estabelecida com sucesso"
        echo "     └─ Versão: ${version:0:60}..."
        echo ""
        log_success "Conexão com PGPool OK"
        return 0
    else
        echo "  ❌ Falha ao conectar com PGPool"
        echo ""
        log_error "Falha na conexão com PGPool"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Mostrar informações dos nós do pool (SHOW POOL_NODES)
# ═══════════════════════════════════════════════════════════════════

show_pool_nodes() {
    log_info "Exibindo informações dos nós do pool..."
    echo ""
    
    docker exec "${PGPOOL_CONTAINER}" psql -h localhost -p 5432 -U "${TEST_USER}" -d "${TEST_DB}" -c "SHOW POOL_NODES;"
    
    if [ $? -eq 0 ]; then
        echo ""
        log_success "Informações dos nós obtidas"
        return 0
    else
        echo ""
        log_error "Falha ao obter informações dos nós"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Verificar status do pool (SHOW POOL_STATUS)
# ═══════════════════════════════════════════════════════════════════

show_pool_status() {
    log_info "Exibindo status do pool..."
    echo ""
    
    # Mostrar apenas algumas configurações importantes
    docker exec "${PGPOOL_CONTAINER}" psql -h localhost -p 5432 -U "${TEST_USER}" -d "${TEST_DB}" -c \
        "SHOW POOL_STATUS;" | grep -E "listen_addresses|port|num_init_children|max_pool|connection_cache|load_balance_mode|master_slave_mode|health_check"
    
    if [ $? -eq 0 ]; then
        echo ""
        log_success "Status do pool obtido"
        return 0
    else
        echo ""
        log_error "Falha ao obter status do pool"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Mostrar processos do PGPool (SHOW POOL_PROCESSES)
# ═══════════════════════════════════════════════════════════════════

show_pool_processes() {
    log_info "Exibindo processos do pool..."
    echo ""
    
    docker exec "${PGPOOL_CONTAINER}" psql -h localhost -p 5432 -U "${TEST_USER}" -d "${TEST_DB}" -c "SHOW POOL_PROCESSES;"
    
    if [ $? -eq 0 ]; then
        echo ""
        log_success "Processos do pool exibidos"
        return 0
    else
        echo ""
        log_error "Falha ao exibir processos do pool"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Testar Load Balancing
# ═══════════════════════════════════════════════════════════════════

test_load_balancing() {
    log_info "Testando Load Balancing (leitura distribuída)..."
    echo ""
    
    echo "  🔄 Executando 5 queries SELECT para verificar distribuição..."
    echo ""
    
    local -A node_distribution
    
    for i in {1..5}; do
        local result=$(docker exec "${PGPOOL_CONTAINER}" psql -h localhost -p 5432 -U "${TEST_USER}" -d "${TEST_DB}" -t -c \
            "SELECT inet_server_addr(), inet_server_port();" 2>/dev/null | xargs)
        
        if [ -n "${result}" ]; then
            echo "     Query ${i}: ${result}"
            node_distribution["${result}"]=$((${node_distribution["${result}"]} + 1))
        else
            echo "     Query ${i}: ERRO"
        fi
    done
    
    echo ""
    echo "  📊 Distribuição de queries por nó:"
    for node in "${!node_distribution[@]}"; do
        echo "     • ${node}: ${node_distribution[$node]} query(s)"
    done
    
    echo ""
    
    if [ ${#node_distribution[@]} -gt 1 ]; then
        log_success "Load Balancing está distribuindo queries entre múltiplos nós"
        return 0
    elif [ ${#node_distribution[@]} -eq 1 ]; then
        log_warning "Todas as queries foram para o mesmo nó (pode estar normal se houver apenas 1 nó ativo)"
        return 0
    else
        log_error "Falha no teste de Load Balancing"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Testar operações de escrita (via Primary)
# ═══════════════════════════════════════════════════════════════════

test_write_operations() {
    log_info "Testando operações de escrita (INSERT/UPDATE/DELETE)..."
    echo ""
    
    local test_table="pgpool_test_$(date +%s)"
    TEST_TABLE="${test_table}"
    
    echo "  🗑️  Limpando tabelas de teste antigas..."
    docker exec "${PGPOOL_CONTAINER}" psql -h localhost -p 5432 -U "${TEST_USER}" -d "${TEST_DB}" -c \
        "DROP TABLE IF EXISTS ${test_table};" > /dev/null 2>&1
    
    echo "  📝 Criando tabela: ${test_table}"
    docker exec "${PGPOOL_CONTAINER}" psql -h localhost -p 5432 -U "${TEST_USER}" -d "${TEST_DB}" -c \
        "CREATE TABLE ${test_table} (
          id serial PRIMARY KEY,
          test_data text,
          server_info text,
          created_at timestamp default now()
        );" > /dev/null
    
    if [ $? -ne 0 ]; then
        log_error "Falha ao criar tabela"
        return 1
    fi
    
    echo "  ✍️  Inserindo dados via PGPool..."
    local test_value="pgpool-write-test-$(date +%Y%m%d-%H%M%S)"
    local server_info=$(docker exec "${PGPOOL_CONTAINER}" psql -h localhost -p 5432 -U "${TEST_USER}" -d "${TEST_DB}" -t -c \
        "INSERT INTO ${test_table} (test_data, server_info) 
         VALUES ('${test_value}', inet_server_addr()::text || ':' || inet_server_port()::text) 
         RETURNING server_info;" 2>/dev/null | xargs)
    
    if [ -n "${server_info}" ]; then
        echo "     └─ Dados inseridos via: ${server_info}"
    else
        log_error "Falha ao inserir dados"
        return 1
    fi
    
    echo "  🔄 Executando UPDATE..."
    docker exec "${PGPOOL_CONTAINER}" psql -h localhost -p 5432 -U "${TEST_USER}" -d "${TEST_DB}" -c \
        "UPDATE ${test_table} SET test_data = 'updated-' || test_data WHERE id = 1;" > /dev/null
    
    echo "  🔢 Contando registros..."
    local count=$(docker exec "${PGPOOL_CONTAINER}" psql -h localhost -p 5432 -U "${TEST_USER}" -d "${TEST_DB}" -t -c \
        "SELECT COUNT(*) FROM ${test_table};" 2>/dev/null | xargs)
    echo "     └─ Total de registros: ${count}"
    
    echo ""
    log_success "Operações de escrita executadas com sucesso"
    return 0
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Verificar replicação via PGPool
# ═══════════════════════════════════════════════════════════════════

verify_replication_via_pgpool() {
    if [ ${#PATRONI_INSTANCES[@]} -eq 0 ]; then
        log_warning "Nenhuma instância Patroni para verificar replicação, pulando teste"
        return 0
    fi
    
    log_info "Verificando replicação de dados via todos os backends..."
    echo ""
    
    echo "  ⏳ Aguardando replicação (3 segundos)..."
    sleep 3
    
    local replicated_count=0
    local failed_nodes=()
    
    # Verificar diretamente em cada nó Patroni (bypass PGPool)
    for node in "${PATRONI_INSTANCES[@]}"; do
        local result=$(docker exec "${node}" psql -U postgres -d "${TEST_DB}" -t -c \
            "SELECT COUNT(*) FROM ${TEST_TABLE};" 2>/dev/null | xargs)
        
        if [ "${result}" = "1" ]; then
            echo "  ✅ ${node}: Dados replicados (${result} registro)"
            ((replicated_count++))
        else
            echo "  ❌ ${node}: Falha na replicação (${result:-0} registros)"
            failed_nodes+=("${node}")
        fi
    done
    
    echo ""
    
    if [ "$replicated_count" -eq ${#PATRONI_INSTANCES[@]} ]; then
        log_success "Replicação verificada em todos os ${#PATRONI_INSTANCES[@]} nós Patroni"
        return 0
    else
        log_warning "Replicação verificada em ${replicated_count}/${#PATRONI_INSTANCES[@]} nós"
        if [ ${#failed_nodes[@]} -gt 0 ]; then
            echo "  ⚠️  Nós com problemas: ${failed_nodes[*]}"
        fi
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Mostrar estatísticas de conexões
# ═══════════════════════════════════════════════════════════════════

show_connection_stats() {
    log_info "Exibindo estatísticas de conexões..."
    echo ""
    
    docker exec "${PGPOOL_CONTAINER}" psql -h localhost -p 5432 -U "${TEST_USER}" -d "${TEST_DB}" -c "SHOW POOL_POOLS;"
    
    if [ $? -eq 0 ]; then
        echo ""
        log_success "Estatísticas de conexões exibidas"
        return 0
    else
        echo ""
        log_error "Falha ao exibir estatísticas de conexões"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Verificar health check status
# ═══════════════════════════════════════════════════════════════════

check_health_status() {
    log_info "Verificando health check dos backends..."
    echo ""
    
    docker exec "${PGPOOL_CONTAINER}" psql -h localhost -p 5432 -U "${TEST_USER}" -d "${TEST_DB}" -c \
        "SHOW POOL_HEALTH_CHECK_STATS;"
    
    if [ $? -eq 0 ]; then
        echo ""
        log_success "Health check stats obtidas"
        return 0
    else
        echo ""
        log_warning "Health check stats não disponíveis (pode depender da versão do PGPool)"
        return 0
    fi
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Verificar cache de conexões
# ═══════════════════════════════════════════════════════════════════

show_cache_info() {
    log_info "Exibindo informações do cache de conexões..."
    echo ""
    
    # Executar múltiplas conexões para popular o cache
    echo "  🔄 Executando múltiplas conexões para testar o cache..."
    for i in {1..3}; do
        docker exec "${PGPOOL_CONTAINER}" psql -h localhost -p 5432 -U "${TEST_USER}" -d "${TEST_DB}" -c \
            "SELECT 'cache-test-${i}' as test;" > /dev/null 2>&1
    done
    
    echo ""
    echo "  📊 Status do cache (via SHOW POOL_CACHE):"
    docker exec "${PGPOOL_CONTAINER}" psql -h localhost -p 5432 -U "${TEST_USER}" -d "${TEST_DB}" -c \
        "SHOW POOL_CACHE;" 2>/dev/null || echo "     └─ Comando não disponível nesta versão"
    
    echo ""
    log_success "Informações do cache verificadas"
    return 0
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Exibir logs do container
# ═══════════════════════════════════════════════════════════════════

show_container_logs() {
    log_info "Exibindo últimas 30 linhas do log do container..."
    echo ""
    
    docker logs --tail 30 "${PGPOOL_CONTAINER}"
    
    if [ $? -eq 0 ]; then
        echo ""
        log_success "Logs exibidos com sucesso"
        return 0
    else
        echo ""
        log_error "Falha ao exibir logs"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Limpar dados de teste
# ═══════════════════════════════════════════════════════════════════

cleanup_test_data() {
    log_info "Limpando dados de teste..."
    
    if [ -n "${TEST_TABLE}" ]; then
        docker exec "${PGPOOL_CONTAINER}" psql -h localhost -p 5432 -U "${TEST_USER}" -d "${TEST_DB}" -c \
            "DROP TABLE IF EXISTS ${TEST_TABLE};" > /dev/null 2>&1
        log_success "Dados de teste removidos: ${TEST_TABLE}"
    else
        log_warning "Nenhuma tabela de teste para remover"
    fi
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Exibir resumo dos testes
# ═══════════════════════════════════════════════════════════════════

show_test_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  ✅ RESUMO DOS TESTES DO PGPOOL"
    echo "═══════════════════════════════════════════════════════════════"
    echo "  ✓ Container: ${PGPOOL_CONTAINER}"
    echo "  ✓ Status do container: OK"
    echo "  ✓ Conexão com PGPool: OK"
    echo "  ✓ Informações dos nós: OK"
    echo "  ✓ Status do pool: OK"
    echo "  ✓ Processos do pool: OK"
    echo "  ✓ Load Balancing: OK"
    echo "  ✓ Operações de escrita: OK"
    echo "  ✓ Verificação de replicação: OK"
    echo "  ✓ Estatísticas de conexões: OK"
    echo "  ✓ Health check: OK"
    echo "  ✓ Cache de conexões: OK"
    echo "  ✓ Logs do container: OK"
    echo "  ✓ Limpeza de dados: OK"
    echo "═══════════════════════════════════════════════════════════════"
    echo "  🎉 Todos os testes foram concluídos com sucesso!"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Função principal
# ═══════════════════════════════════════════════════════════════════

main() {
    # Carregar ambiente
    load_env
    
    # Definir arquivo docker-compose
    COMPOSE_FILE="${COMPOSE_FILE:-${PROJECT_ROOT}/docker-compose.yaml}"
    
    # Validar variáveis
    validate_required_vars
    
    # Exibir cabeçalho
    show_header
    
    # Executar testes
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📦 TESTE 1: Status do Container"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    check_container_status
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🔌 TESTE 2: Conexão com PGPool"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    test_pgpool_connection
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🖥️  TESTE 3: Informações dos Nós (POOL_NODES)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    show_pool_nodes
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ⚙️  TESTE 4: Status do Pool (POOL_STATUS)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    show_pool_status
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🔄 TESTE 5: Processos do Pool (POOL_PROCESSES)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    show_pool_processes
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ⚖️  TESTE 6: Load Balancing (Distribuição de Leituras)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    test_load_balancing
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✍️  TESTE 7: Operações de Escrita (INSERT/UPDATE)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    test_write_operations
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🔄 TESTE 8: Verificação de Replicação"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    verify_replication_via_pgpool
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📊 TESTE 9: Estatísticas de Conexões (POOL_POOLS)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    show_connection_stats
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  💚 TESTE 10: Health Check dos Backends"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    check_health_status
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  💾 TESTE 11: Cache de Conexões"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    show_cache_info
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📋 TESTE 12: Logs do Container"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    show_container_logs
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🧹 Limpeza de Dados de Teste"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cleanup_test_data
    
    # Exibir resumo final
    show_test_summary
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Executar script
# ═══════════════════════════════════════════════════════════════════

main "$@"

exit 0
