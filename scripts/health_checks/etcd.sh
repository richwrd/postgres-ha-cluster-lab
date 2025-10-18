#!/bin/bash
# ------------------------------------------------------------------------------------
# Script de testes ETCD
# by: richwrd
# ------------------------------------------------------------------------------------

# ═══════════════════════════════════════════════════════════════════
# ◉➔ TESTES ETCD
# ═══════════════════════════════════════════════════════════════════

test_etcd_containers() {
    increment_test
    log_info "Verificando containers ETCD..."
    
    local running_count=0
    local failed_instances=()
    
    for instance in "${ETCD_INSTANCES[@]}"; do
        if docker ps --filter "name=${instance}" --filter "status=running" --format "{{.Names}}" | grep -q "^${instance}$"; then
            echo "  ✅ ${instance}: Rodando"
            ((running_count++))
        else
            echo "  ❌ ${instance}: Parado"
            failed_instances+=("${instance}")
        fi
    done
    
    if [ "$running_count" -eq ${#ETCD_INSTANCES[@]} ]; then
        echo "  ✓ Todos os ${#ETCD_INSTANCES[@]} containers ETCD estão rodando"
        test_passed
        return 0
    else
        echo "  ✗ Problemas detectados (${running_count}/${#ETCD_INSTANCES[@]} rodando)"
        test_failed
        return 1
    fi
}

test_etcd_health() {
    increment_test
    log_info "Verificando saúde do cluster ETCD..."
    
    local first_instance="${ETCD_INSTANCES[0]}"
    
    if docker exec "${first_instance}" etcdctl endpoint health \
        --endpoints="${ETCD_ENDPOINTS}" &>/dev/null; then
        echo "  ✅ Cluster ETCD saudável"
        test_passed
        return 0
    else
        echo "  ❌ Problemas na saúde do cluster ETCD"
        test_failed
        return 1
    fi
}

test_etcd_write_read() {
    increment_test
    log_info "Testando escrita/leitura no ETCD..."
    
    local first_instance="${ETCD_INSTANCES[0]}"
    local test_key="/healthcheck/$(date +%s)"
    local test_value="ok-$(date +%Y%m%d-%H%M%S)"
    
    # Escrever
    docker exec "${first_instance}" etcdctl put "${test_key}" "${test_value}" &>/dev/null
    
    # Ler
    local result=$(docker exec "${first_instance}" etcdctl get "${test_key}" --print-value-only 2>/dev/null)
    
    # Limpar
    docker exec "${first_instance}" etcdctl del "${test_key}" &>/dev/null
    
    if [ "$result" = "$test_value" ]; then
        echo "  ✅ Operações de escrita/leitura: OK"
        test_passed
        return 0
    else
        echo "  ❌ Falha nas operações de escrita/leitura"
        test_failed
        return 1
    fi
}
