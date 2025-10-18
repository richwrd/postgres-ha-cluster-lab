#!/bin/bash
# ------------------------------------------------------------------------------------
# Script consolidado para verificação de status do cluster PostgreSQL HA
# Testa: ETCD, Patroni e PGPool
# 
# Estrutura Modular:
#   - etcd.sh     : Testes do cluster ETCD
#   - patroni.sh  : Testes do cluster Patroni PostgreSQL
#   - pgpool.sh   : Testes do PGPool-II (connection pooling e load balancing)
#
# by: richwrd
# ------------------------------------------------------------------------------------

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Carregar bibliotecas de ambiente
# ═══════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/env.sh"
source "${SCRIPT_DIR}/../lib/logging.sh"

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Carregar módulos de testes específicos
# ═══════════════════════════════════════════════════════════════════

source "${SCRIPT_DIR}/etcd.sh"
source "${SCRIPT_DIR}/patroni.sh"
source "${SCRIPT_DIR}/pgpool.sh"

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Variáveis globais
# ═══════════════════════════════════════════════════════════════════

declare -a ETCD_INSTANCES
declare -a PATRONI_INSTANCES
declare PATRONI_PRIMARY
declare PGPOOL_CONTAINER
declare COMPOSE_FILE
declare ETCD_ENDPOINTS

declare TEST_DB="postgres"

# Contadores de testes
declare TOTAL_TESTS=0
declare PASSED_TESTS=0
declare FAILED_TESTS=0

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Funções auxiliares de contagem
# ═══════════════════════════════════════════════════════════════════

increment_test() {
    ((TOTAL_TESTS++))
}

test_passed() {
    ((PASSED_TESTS++))
}

test_failed() {
    ((FAILED_TESTS++))
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Carregar variáveis de ambiente
# ═══════════════════════════════════════════════════════════════════

load_cluster_vars() {
    log_info "Carregando variáveis de ambiente do cluster..."
    
    # Carregar ETCD
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
    
    # Construir endpoints ETCD
    local endpoints=""
    for instance in "${ETCD_INSTANCES[@]}"; do
        if [ -z "$endpoints" ]; then
            endpoints="http://${instance}:2379"
        else
            endpoints="${endpoints},http://${instance}:2379"
        fi
    done
    ETCD_ENDPOINTS="${endpoints}"
    export ETCD_ENDPOINTS
    
    # Carregar Patroni
    PATRONI_INSTANCES=()
    idx=1
    while true; do
        local var_name="PATRONI${idx}_NAME"
        local instance_name="${!var_name}"
        
        if [ -z "${instance_name}" ]; then
            break
        fi
        
        PATRONI_INSTANCES+=("${instance_name}")
        ((idx++))
    done
    
    # Carregar PGPool
    PGPOOL_CONTAINER="${PGPOOL_NAME}"
    
    echo ""
    echo "  📋 Configuração do cluster:"
    echo "     • Instâncias ETCD: ${#ETCD_INSTANCES[@]}"
    echo "     • Instâncias Patroni: ${#PATRONI_INSTANCES[@]}"
    echo "     • Container PGPool: ${PGPOOL_CONTAINER}"
    echo "     • Usuário DB: ${TEST_DB_USERNAME:-<não definido>}"
    echo ""
    
    log_success "Variáveis de ambiente carregadas"
}


# ═══════════════════════════════════════════════════════════════════
# ◉➔ Exibir cabeçalho
# ═══════════════════════════════════════════════════════════════════

show_header() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  🔍 VERIFICAÇÃO DE STATUS DO CLUSTER POSTGRESQL HA"
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Data/Hora: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "  Compose File: ${COMPOSE_FILE}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Exibir resumo final
# ═══════════════════════════════════════════════════════════════════

show_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  📊 RESUMO DA VERIFICAÇÃO"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    # Calcular percentual de sucesso
    local success_percent=0
    if [ $TOTAL_TESTS -gt 0 ]; then
        success_percent=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi
    
    echo "  📈 Estatísticas:"
    echo "     • Total de testes: ${TOTAL_TESTS}"
    echo "     • Testes passados: ${PASSED_TESTS} (${success_percent}%)"
    echo "     • Testes falhados: ${FAILED_TESTS}"
    echo ""
    
    echo "  🔧 Componentes:"
    echo "     • ETCD: ${#ETCD_INSTANCES[@]} instância(s)"
    echo "     • Patroni: ${#PATRONI_INSTANCES[@]} instância(s)"
    echo "     • PGPool: 1 instância"
    echo ""
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo "  ✅ STATUS GERAL: TODOS OS TESTES PASSARAM"
        echo "  🎉 Cluster está operacional e saudável!"
    elif [ $FAILED_TESTS -lt 3 ]; then
        echo "  ⚠️  STATUS GERAL: ALERTAS DETECTADOS"
        echo "  ⚡ Cluster operacional com alguns problemas menores"
    else
        echo "  ❌ STATUS GERAL: PROBLEMAS CRÍTICOS DETECTADOS"
        echo "  🚨 Cluster requer atenção imediata!"
    fi
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    # Retornar código de saída apropriado
    if [ $FAILED_TESTS -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Função principal
# ═══════════════════════════════════════════════════════════════════

main() {
    # Carregar ambiente
    load_env
    
    # Definir arquivo docker-compose
    COMPOSE_FILE="${COMPOSE_FILE:-${PROJECT_ROOT}/docker-compose.yaml}"
    
    # Carregar variáveis do cluster
    load_cluster_vars
    
    # Exibir cabeçalho
    show_header
    
    # ═══════════════════════════════════════════════════════════════
    # TESTES ETCD
    # ═══════════════════════════════════════════════════════════════
    
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│ 🔷 TESTES DO ETCD                                           │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    
    test_etcd_containers
    echo ""
    
    test_etcd_health
    echo ""
    
    test_etcd_write_read
    echo ""
    
    # ═══════════════════════════════════════════════════════════════
    # TESTES PATRONI
    # ═══════════════════════════════════════════════════════════════
    
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│ 🔷 TESTES DO PATRONI                                        │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    
    test_patroni_containers
    echo ""
    
    identify_patroni_primary
    echo ""
    
    test_patroni_health
    echo ""
    
    test_patroni_replication
    echo ""
    
    # ═══════════════════════════════════════════════════════════════
    # TESTES PGPOOL
    # ═══════════════════════════════════════════════════════════════
    
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│ 🔷 TESTES DO PGPOOL                                         │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    
    test_pgpool_container
    echo ""
    
    # Detectar credenciais válidas antes de continuar
    detect_pgpool_credentials
    echo ""
    
    test_pgpool_connection
    echo ""
    
    test_pgpool_backends
    echo ""
    
    test_pgpool_load_balancing
    echo ""
    
    test_pgpool_write_operations
    echo ""
    
    # ═══════════════════════════════════════════════════════════════
    # RESUMO FINAL
    # ═══════════════════════════════════════════════════════════════
    
    show_summary
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Executar script
# ═══════════════════════════════════════════════════════════════════

main "$@"

exit_code=$?
exit $exit_code
