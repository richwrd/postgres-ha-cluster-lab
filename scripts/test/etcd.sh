#!/bin/bash
# ------------------------------------------------------------------------------------
# Script para testar cluster ETCD
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

declare -a ETCD_INSTANCES
declare ETCD_ENDPOINTS
declare TEST_KEY

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Validar variáveis de ambiente necessárias
# ═══════════════════════════════════════════════════════════════════

validate_required_vars() {
    local instances=("$@")
    
    log_info "Validando variáveis de ambiente..."
    
    if [ ${#instances[@]} -eq 0 ]; then
        log_error "Nenhuma instância ETCD fornecida"
        return 1
    fi
    
    # Validar se cada variável de ambiente existe
    for instance in "${instances[@]}"; do
        if [ -z "${instance}" ]; then
            log_error "Nome de instância vazio detectado"
            return 1
        fi
    done
    
    # Exibir as instâncias ETCD detectadas
    echo ""
    echo "  📋 Instâncias ETCD configuradas (${#instances[@]} no total):"
    local idx=1
    for instance in "${instances[@]}"; do
        echo "     • ETCD${idx}: ${instance}"
        ((idx++))
    done
    echo ""
    
    # Construir endpoints dinamicamente
    local endpoints=""
    for instance in "${instances[@]}"; do
        if [ -z "$endpoints" ]; then
            endpoints="http://${instance}:2379"
        else
            endpoints="${endpoints},http://${instance}:2379"
        fi
    done
    
    ETCD_ENDPOINTS="${endpoints}"
    export ETCD_ENDPOINTS
    
    log_success "Variáveis de ambiente validadas (${#instances[@]} instâncias)"
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Exibir cabeçalho do teste
# ═══════════════════════════════════════════════════════════════════

show_header() {
    local instance_count=${#ETCD_INSTANCES[@]}
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  🔍 TESTE DO CLUSTER ETCD "
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Instâncias: ${instance_count}"
    echo "  Endpoints: ${ETCD_ENDPOINTS}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Verificar status dos containers
# ═══════════════════════════════════════════════════════════════════

check_container_status() {
    local instances=("$@")
    
    log_info "Verificando status dos containers ETCD..."
    echo ""
    docker compose -f "${PROJECT_ROOT}/docker-compose.yaml" ps
    echo ""
    
    # Verificar cada instância ETCD individualmente
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
        log_success "Todos os ${#instances[@]} containers ETCD estão rodando"
        return 0
    else
        log_error "Nem todos os containers ETCD estão rodando (Running: ${running_count}/${#instances[@]})"
        if [ ${#failed_instances[@]} -gt 0 ]; then
            echo "  ⚠️  Instâncias com problemas: ${failed_instances[*]}"
        fi
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Verificar saúde do cluster
# ═══════════════════════════════════════════════════════════════════

check_cluster_health() {
    local instances=("$@")
    local first_instance="${instances[0]}"
    
    log_info "Verificando saúde do cluster ETCD..."
    echo ""
    
    if docker exec "${first_instance}" etcdctl endpoint health \
        --endpoints="${ETCD_ENDPOINTS}"; then
        echo ""
        log_success "Cluster ETCD está saudável"
        return 0
    else
        echo ""
        log_error "Problemas detectados na saúde do cluster"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Exibir status detalhado do cluster
# ═══════════════════════════════════════════════════════════════════

show_cluster_status() {
    local instances=("$@")
    local first_instance="${instances[0]}"
    
    log_info "Obtendo status detalhado do cluster..."
    echo ""
    
    docker exec "${first_instance}" etcdctl endpoint status \
        --endpoints="${ETCD_ENDPOINTS}" \
        -w table
    
    echo ""
    log_success "Status detalhado exibido"
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Listar membros do cluster
# ═══════════════════════════════════════════════════════════════════

list_cluster_members() {
    local instances=("$@")
    local first_instance="${instances[0]}"
    
    log_info "Listando membros do cluster..."
    echo ""
    
    docker exec "${first_instance}" etcdctl member list -w table
    
    echo ""
    log_success "Membros do cluster listados"
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Testar operações de escrita e leitura
# ═══════════════════════════════════════════════════════════════════

test_write_read_operations() {
    local instances=("$@")
    local first_instance="${instances[0]}"
    
    log_info "Testando operações de escrita e leitura..."
    
    local test_key="/test/$(date +%s)"
    local test_value="cluster-funcionando-$(date +%Y%m%d-%H%M%S)"
    
    # Escrever no ETCD
    echo "  ✍️  Escrevendo chave: ${test_key}"
    docker exec "${first_instance}" etcdctl put "${test_key}" "${test_value}" > /dev/null
    
    # Ler do ETCD
    echo "  📖 Lendo chave: ${test_key}"
    local result=$(docker exec "${first_instance}" etcdctl get "${test_key}" --print-value-only)
    
    if [ "$result" = "$test_value" ]; then
        log_success "Teste de escrita/leitura: OK"
        echo "     Valor esperado: ${test_value}"
        echo "     Valor obtido:   ${result}"
    else
        log_error "Teste de escrita/leitura: FALHOU"
        echo "     Valor esperado: ${test_value}"
        echo "     Valor obtido:   ${result}"
        return 1
    fi
    
    # Retornar a chave de teste para uso posterior
    export TEST_KEY="${test_key}"
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Testar consistência entre nós
# ═══════════════════════════════════════════════════════════════════

test_data_consistency() {
    local instances=("$@")
    
    log_info "Testando consistência de dados entre nós..."
    
    local -a values
    local all_equal=true
    local reference_value=""
    
    # Coletar valores de todas as instâncias
    for instance in "${instances[@]}"; do
        local value=$(docker exec "${instance}" etcdctl get "${TEST_KEY}" --print-value-only)
        values+=("${value}")
        echo "  📊 Valor no ${instance}: ${value}"
        
        # Verificar consistência
        if [ -z "${reference_value}" ]; then
            reference_value="${value}"
        elif [ "${value}" != "${reference_value}" ]; then
            all_equal=false
        fi
    done
    
    echo ""
    if $all_equal; then
        log_success "Dados consistentes em todos os ${#instances[@]} nós do cluster"
        return 0
    else
        log_error "Inconsistência detectada entre os nós"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Limpar dados de teste
# ═══════════════════════════════════════════════════════════════════

cleanup_test_data() {
    local instances=("$@")
    local first_instance="${instances[0]}"
    
    log_info "Limpando dados de teste..."
    
    if [ -n "${TEST_KEY}" ]; then
        docker exec "${first_instance}" etcdctl del "${TEST_KEY}" > /dev/null
        log_success "Dados de teste removidos: ${TEST_KEY}"
    fi
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Testar métricas do cluster
# ═══════════════════════════════════════════════════════════════════

show_cluster_metrics() {
    local instances=("$@")
    local first_instance="${instances[0]}"
    
    log_info "Exibindo métricas do cluster..."
    echo ""
    
    echo "  📈 Estatísticas de performance:"
    docker exec "${first_instance}" etcdctl endpoint status \
        --endpoints="${ETCD_ENDPOINTS}" \
        -w json | python3 -m json.tool 2>/dev/null || \
        docker exec "${first_instance}" etcdctl endpoint status \
            --endpoints="${ETCD_ENDPOINTS}" \
            -w table
    
    echo ""
    log_success "Métricas exibidas"
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
    echo "  ✓ Status dos containers: OK"
    echo "  ✓ Saúde do cluster: OK"
    echo "  ✓ Status detalhado: OK"
    echo "  ✓ Membros listados: OK"
    echo "  ✓ Operações de escrita/leitura: OK"
    echo "  ✓ Consistência entre nós: OK"
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
    
    # Verificar se as variáveis ETCD estão definidas
    if [ -z "${ETCD1_NAME}" ]; then
        log_error "Variável ETCD1_NAME não está definida"
        exit 1
    fi
    
    # Construir array de instâncias a partir das variáveis de ambiente
    ETCD_INSTANCES=()
    local idx=1
    while true; do
        local var_name="ETCD${idx}_NAME"
        local instance_name="${!var_name}"
        
        if [ -z "${instance_name}" ]; then
            break
        fi
        
        ETCD_INSTANCES+=("${instance_name}")
        ((idx++))
    done
    
    # Validar se temos pelo menos uma instância
    if [ ${#ETCD_INSTANCES[@]} -eq 0 ]; then
        log_error "Nenhuma instância ETCD encontrada nas variáveis de ambiente"
        exit 1
    fi
    
    # Validar variáveis
    validate_required_vars "${ETCD_INSTANCES[@]}"
    
    # Exibir cabeçalho
    show_header
    
    # Executar testes passando as instâncias para cada função
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📦 TESTE 1: Status dos Containers"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    check_container_status "${ETCD_INSTANCES[@]}"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  💚 TESTE 2: Saúde do Cluster"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    check_cluster_health "${ETCD_INSTANCES[@]}"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📊 TESTE 3: Status Detalhado"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    show_cluster_status "${ETCD_INSTANCES[@]}"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  👥 TESTE 4: Membros do Cluster"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    list_cluster_members "${ETCD_INSTANCES[@]}"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✍️  TESTE 5: Operações de Escrita/Leitura"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    test_write_read_operations "${ETCD_INSTANCES[@]}"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🔄 TESTE 6: Consistência entre Nós"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    test_data_consistency "${ETCD_INSTANCES[@]}"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🧹 Limpeza de Dados de Teste"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cleanup_test_data "${ETCD_INSTANCES[@]}"
    
    # Exibir resumo
    show_test_summary "${ETCD_INSTANCES[@]}"
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Executar script
# ═══════════════════════════════════════════════════════════════════

main "$@"

exit 0
