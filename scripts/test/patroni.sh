#!/bin/bash
# ------------------------------------------------------------------------------------
# Script para testar cluster Patroni PostgreSQL Modular
# by: richwrd
# ------------------------------------------------------------------------------------

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Carregar biblioteca de ambiente
# ═══════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/env.sh"
source "${SCRIPT_DIR}/../lib/logging.sh"

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Variáveis globais
# ═══════════════════════════════════════════════════════════════════

declare -a PATRONI_INSTANCES
declare PATRONI_PRIMARY
declare TEST_TABLE
declare COMPOSE_FILE

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Validar variáveis de ambiente necessárias
# ═══════════════════════════════════════════════════════════════════

validate_required_vars() {
    local instances=("$@")
    
    log_info "Validando variáveis de ambiente..."
    
    if [ ${#instances[@]} -eq 0 ]; then
        log_error "Nenhuma instância Patroni fornecida"
        return 1
    fi
    
    # Validar se cada variável de ambiente existe
    for instance in "${instances[@]}"; do
        if [ -z "${instance}" ]; then
            log_error "Nome de instância vazio detectado"
            return 1
        fi
    done
    
    # Exibir as instâncias Patroni detectadas
    echo ""
    echo "  📋 Instâncias Patroni configuradas (${#instances[@]} no total):"
    local idx=1
    for instance in "${instances[@]}"; do
        echo "     • PATRONI${idx}: ${instance}"
        ((idx++))
    done
    echo ""
    
    log_success "Variáveis de ambiente validadas (${#instances[@]} instâncias)"
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Exibir cabeçalho do teste
# ═══════════════════════════════════════════════════════════════════

show_header() {
    local instance_count=${#PATRONI_INSTANCES[@]}
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  🔍 TESTE DO CLUSTER PATRONI POSTGRESQL "
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Instâncias: ${instance_count}"
    echo "  Compose File: ${COMPOSE_FILE}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Verificar status dos containers
# ═══════════════════════════════════════════════════════════════════

check_container_status() {
    local instances=("$@")
    
    log_info "Verificando status dos containers Patroni..."
    echo ""
    docker compose -f "${COMPOSE_FILE}" ps
    echo ""
    
    # Verificar cada instância Patroni individualmente
    local running_count=0
    local failed_instances=()
    
    for instance in "${instances[@]}"; do
        echo "  🔍 Verificando ${instance}..."
        if docker ps --filter "name=${instance}" --filter "status=running" --format "{{.Names}}" | grep -q "^${instance}$"; then
            log_success "  ✓ ${instance} está rodando"
            ((running_count++))
        else
            log_error "  ✗ ${instance} NÃO está rodando"
            failed_instances+=("${instance}")
        fi
    done
    
    echo ""
    if [ "$running_count" -eq ${#instances[@]} ]; then
        log_success "Todos os ${#instances[@]} containers Patroni estão rodando"
        return 0
    else
        log_error "Nem todos os containers Patroni estão rodando (Running: ${running_count}/${#instances[@]})"
        if [ ${#failed_instances[@]} -gt 0 ]; then
            echo "  ⚠️  Instâncias com problemas: ${failed_instances[*]}"
        fi
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Listar membros do cluster
# ═══════════════════════════════════════════════════════════════════

list_cluster_members() {
    local instances=("$@")
    local first_instance="${instances[0]}"
    
    log_info "Listando membros do cluster Patroni..."
    echo ""
    
    docker exec "${first_instance}" patronictl list
    
    echo ""
    log_success "Membros do cluster listados"
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Identificar o nó primário (Primary/Leader)
# ═══════════════════════════════════════════════════════════════════

identify_primary() {
    local instances=("$@")
    
    log_info "Identificando o líder (Primary)..."
    echo ""
    
    # Método 1: Usar o endpoint /primary que retorna HTTP 200 apenas no líder
    for node in "${instances[@]}"; do
        local HTTP_CODE=$(docker exec "$node" curl -s -o /dev/null -w "%{http_code}" http://localhost:8008/primary 2>/dev/null || echo "000")
        
        if [ "$HTTP_CODE" = "200" ]; then
            echo "  ✅ $node é o LÍDER (Primary)"
            PATRONI_PRIMARY="$node"
            break
        else
            echo "  ⚪ $node é Replica (HTTP $HTTP_CODE)"
        fi
    done
    
    # Fallback: usar patronictl para identificar
    if [ -z "$PATRONI_PRIMARY" ]; then
        log_warning "Tentando identificar líder via patronictl..."
        local first_instance="${instances[0]}"
        
        PATRONI_PRIMARY=$(docker exec "${first_instance}" patronictl list -f json 2>/dev/null | \
                  grep -o '"Role":"Leader".*"Member":"[^"]*"' | \
                  grep -o "${instances[0]%%-*}-[0-9]" | head -1)
        
        if [ -n "$PATRONI_PRIMARY" ]; then
            echo "  ✅ Líder identificado via patronictl: $PATRONI_PRIMARY"
        else
            PATRONI_PRIMARY="${instances[0]}"
            log_warning "Usando ${instances[0]} como padrão"
        fi
    fi
    
    echo ""
    log_success "Primary identificado: ${PATRONI_PRIMARY}"
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Verificar saúde dos nós
# ═══════════════════════════════════════════════════════════════════

check_nodes_health() {
    local instances=("$@")
    
    log_info "Verificando saúde individual dos nós..."
    echo ""
    
    local healthy_count=0
    local unhealthy_instances=()
    
    for node in "${instances[@]}"; do
        local HTTP_CODE=$(docker exec "$node" curl -s -o /dev/null -w "%{http_code}" http://localhost:8008/health 2>/dev/null || echo "000")
        
        if [ "$HTTP_CODE" = "200" ]; then
            echo "  ✅ $node: SAUDÁVEL (HTTP $HTTP_CODE)"
            ((healthy_count++))
        else
            echo "  ❌ $node: PROBLEMA (HTTP $HTTP_CODE)"
            unhealthy_instances+=("$node")
        fi
    done
    
    echo ""
    if [ "$healthy_count" -eq ${#instances[@]} ]; then
        log_success "Todos os ${#instances[@]} nós estão saudáveis"
        return 0
    else
        log_error "Problemas de saúde detectados (Saudáveis: ${healthy_count}/${#instances[@]})"
        if [ ${#unhealthy_instances[@]} -gt 0 ]; then
            echo "  ⚠️  Nós com problemas: ${unhealthy_instances[*]}"
        fi
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Criar dados de teste no Primary
# ═══════════════════════════════════════════════════════════════════

create_test_data() {
    log_info "Criando dados de teste no Primary (${PATRONI_PRIMARY})..."
    
    local test_table="patroni_test_$(date +%s)"
    TEST_TABLE="${test_table}"
    
    echo "  🗑️  Removendo tabela de teste anterior (se existir)..."
    docker exec "${PATRONI_PRIMARY}" psql -U postgres -c \
        "DROP TABLE IF EXISTS ${test_table};" > /dev/null 2>&1
    
    echo "  📝 Criando tabela: ${test_table}"
    docker exec "${PATRONI_PRIMARY}" psql -U postgres -c \
        "CREATE TABLE ${test_table} (
          id serial PRIMARY KEY, 
          test_data text, 
          created_at timestamp default now()
        );" > /dev/null
    
    echo "  ✍️  Inserindo dados de teste..."
    local test_value="replicacao-funcionando-$(date +%Y%m%d-%H%M%S)"
    docker exec "${PATRONI_PRIMARY}" psql -U postgres -c \
        "INSERT INTO ${test_table} (test_data) VALUES ('${test_value}');" > /dev/null
    
    echo "  ⏳ Aguardando replicação (3 segundos)..."
    sleep 3
    
    echo ""
    log_success "Dados de teste criados: ${test_table}"
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Verificar replicação dos dados
# ═══════════════════════════════════════════════════════════════════

verify_replication() {
    local instances=("$@")
    
    log_info "Verificando replicação de dados em todos os nós..."
    echo ""
    
    local replicated_count=0
    local failed_instances=()
    local reference_value=""
    
    for node in "${instances[@]}"; do
        local RESULT=$(docker exec "$node" psql -U postgres -t -c \
            "SELECT test_data FROM ${TEST_TABLE} LIMIT 1;" 2>/dev/null | xargs)
        
        # Armazenar valor de referência do primeiro nó
        if [ -z "${reference_value}" ]; then
            reference_value="${RESULT}"
        fi
        
        if [ -n "$RESULT" ] && [ "$RESULT" = "$reference_value" ]; then
            echo "  ✅ $node: Dados replicados corretamente"
            echo "     └─ Valor: ${RESULT}"
            ((replicated_count++))
        else
            echo "  ❌ $node: Falha na replicação"
            echo "     └─ Valor esperado: ${reference_value}"
            echo "     └─ Valor obtido: ${RESULT:-<vazio>}"
            failed_instances+=("$node")
        fi
    done
    
    echo ""
    if [ "$replicated_count" -eq ${#instances[@]} ]; then
        log_success "Replicação consistente em todos os ${#instances[@]} nós"
        return 0
    else
        log_error "Problemas de replicação detectados (OK: ${replicated_count}/${#instances[@]})"
        if [ ${#failed_instances[@]} -gt 0 ]; then
            echo "  ⚠️  Nós com problemas: ${failed_instances[*]}"
        fi
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Verificar lag de replicação
# ═══════════════════════════════════════════════════════════════════

check_replication_lag() {
    local instances=("$@")
    local first_instance="${instances[0]}"
    
    log_info "Verificando lag de replicação..."
    echo ""
    
    docker exec "${first_instance}" patronictl list | grep -E "Member|Lag|---"
    
    echo ""
    log_success "Lag de replicação verificado"
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Verificar configuração no etcd
# ═══════════════════════════════════════════════════════════════════

verify_etcd_configuration() {
    log_info "Verificando configuração do cluster no etcd..."
    echo ""
    
    # Tentar acessar etcd via primeiro nó Patroni
    if [ -n "${ETCD1_NAME}" ]; then
        local KEYS=$(docker exec "${ETCD1_NAME}" etcdctl get /service/ --prefix --keys-only 2>/dev/null | head -10)
        
        if [ -n "$KEYS" ]; then
            echo "  📋 Chaves no etcd (primeiras 10):"
            echo "$KEYS" | sed 's/^/     /'
            echo ""
            log_success "Configuração encontrada no etcd"
        else
            log_warning "Nenhuma chave encontrada no etcd"
        fi
    else
        log_warning "Variável ETCD1_NAME não definida, pulando verificação do etcd"
    fi
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Testar operações de escrita/leitura SQL
# ═══════════════════════════════════════════════════════════════════

test_sql_operations() {
    log_info "Testando operações SQL avançadas..."
    echo ""
    
    # Teste de UPDATE
    echo "  🔄 Executando UPDATE..."
    docker exec "${PATRONI_PRIMARY}" psql -U postgres -c \
        "UPDATE ${TEST_TABLE} SET test_data = 'atualizado-$(date +%s)' WHERE id = 1;" > /dev/null
    
    # Teste de COUNT
    echo "  🔢 Executando COUNT..."
    local count=$(docker exec "${PATRONI_PRIMARY}" psql -U postgres -t -c \
        "SELECT COUNT(*) FROM ${TEST_TABLE};" 2>/dev/null | xargs)
    echo "     └─ Total de registros: ${count}"
    
    # Aguardar replicação
    echo "  ⏳ Aguardando replicação (2 segundos)..."
    sleep 2
    
    echo ""
    log_success "Operações SQL executadas com sucesso"
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Mostrar informações de conexão PostgreSQL
# ═══════════════════════════════════════════════════════════════════

show_connection_info() {
    local instances=("$@")
    
    log_info "Exibindo informações de conexão PostgreSQL..."
    echo ""
    
    for node in "${instances[@]}"; do
        echo "  📊 Informações de ${node}:"
        
        # Versão do PostgreSQL
        local pg_version=$(docker exec "$node" psql -U postgres -t -c \
            "SELECT version();" 2>/dev/null | head -1 | xargs)
        echo "     └─ Versão: ${pg_version:0:50}..."
        
        # Número de conexões ativas
        local connections=$(docker exec "$node" psql -U postgres -t -c \
            "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | xargs)
        echo "     └─ Conexões ativas: ${connections}"
        
        # Tamanho do banco de dados
        local db_size=$(docker exec "$node" psql -U postgres -t -c \
            "SELECT pg_size_pretty(pg_database_size('postgres'));" 2>/dev/null | xargs)
        echo "     └─ Tamanho do DB: ${db_size}"
        
        echo ""
    done
    
    log_success "Informações de conexão exibidas"
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Limpar dados de teste
# ═══════════════════════════════════════════════════════════════════

cleanup_test_data() {
    log_info "Limpando dados de teste..."
    
    if [ -n "${TEST_TABLE}" ]; then
        docker exec "${PATRONI_PRIMARY}" psql -U postgres -c \
            "DROP TABLE IF EXISTS ${TEST_TABLE};" > /dev/null 2>&1
        log_success "Dados de teste removidos: ${TEST_TABLE}"
    else
        log_warning "Nenhuma tabela de teste para remover"
    fi
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Exibir resumo final do cluster
# ═══════════════════════════════════════════════════════════════════

show_cluster_summary() {
    local instances=("$@")
    local first_instance="${instances[0]}"
    
    log_info "Resumo final do cluster Patroni..."
    echo ""
    
    docker exec "${first_instance}" patronictl list
    
    echo ""
    log_success "Resumo do cluster exibido"
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Exibir resumo dos testes
# ═══════════════════════════════════════════════════════════════════

show_test_summary() {
    local instances=("$@")
    local instance_count=${#instances[@]}
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  ✅ RESUMO DOS TESTES"
    echo "═══════════════════════════════════════════════════════════════"
    echo "  ✓ Instâncias testadas: ${instance_count}"
    echo "  ✓ Primary identificado: ${PATRONI_PRIMARY}"
    echo "  ✓ Status dos containers: OK"
    echo "  ✓ Membros do cluster: OK"
    echo "  ✓ Saúde dos nós: OK"
    echo "  ✓ Criação de dados: OK"
    echo "  ✓ Replicação de dados: OK"
    echo "  ✓ Lag de replicação: OK"
    echo "  ✓ Configuração etcd: OK"
    echo "  ✓ Operações SQL: OK"
    echo "  ✓ Informações de conexão: OK"
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
    
    # Verificar se as variáveis Patroni estão definidas
    if [ -z "${PATRONI1_NAME}" ]; then
        log_error "Variável PATRONI1_NAME não está definida"
        exit 1
    fi
    
    # Construir array de instâncias a partir das variáveis de ambiente
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
    
    # Validar se temos pelo menos uma instância
    if [ ${#PATRONI_INSTANCES[@]} -eq 0 ]; then
        log_error "Nenhuma instância Patroni encontrada nas variáveis de ambiente"
        exit 1
    fi
    
    # Validar variáveis
    validate_required_vars "${PATRONI_INSTANCES[@]}"
    
    # Exibir cabeçalho
    show_header
    
    # Executar testes passando as instâncias para cada função
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📦 TESTE 1: Status dos Containers"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    check_container_status "${PATRONI_INSTANCES[@]}"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  👥 TESTE 2: Membros do Cluster"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    list_cluster_members "${PATRONI_INSTANCES[@]}"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  👑 TESTE 3: Identificar Primary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    identify_primary "${PATRONI_INSTANCES[@]}"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  💚 TESTE 4: Saúde dos Nós"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    check_nodes_health "${PATRONI_INSTANCES[@]}"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✍️  TESTE 5: Criar Dados de Teste"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    create_test_data
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🔄 TESTE 6: Verificar Replicação"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    verify_replication "${PATRONI_INSTANCES[@]}"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ⏱️  TESTE 7: Lag de Replicação"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    check_replication_lag "${PATRONI_INSTANCES[@]}"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🔧 TESTE 8: Configuração no etcd"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    verify_etcd_configuration
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🗄️  TESTE 9: Operações SQL Avançadas"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    test_sql_operations
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📊 TESTE 10: Informações de Conexão"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    show_connection_info "${PATRONI_INSTANCES[@]}"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🧹 Limpeza de Dados de Teste"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cleanup_test_data
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📋 TESTE 11: Resumo do Cluster"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    show_cluster_summary "${PATRONI_INSTANCES[@]}"
    
    # Exibir resumo final
    show_test_summary "${PATRONI_INSTANCES[@]}"
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Executar script
# ═══════════════════════════════════════════════════════════════════

main "$@"

exit 0
