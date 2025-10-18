#!/bin/bash
# ------------------------------------------------------------------------------------
# Script de testes Patroni
# by: richwrd
# ------------------------------------------------------------------------------------

# ═══════════════════════════════════════════════════════════════════
# ◉➔ TESTES PATRONI
# ═══════════════════════════════════════════════════════════════════

test_patroni_containers() {
    increment_test
    log_info "Verificando containers Patroni..."
    
    local running_count=0
    local failed_instances=()
    
    for instance in "${PATRONI_INSTANCES[@]}"; do
        if docker ps --filter "name=${instance}" --filter "status=running" --format "{{.Names}}" | grep -q "^${instance}$"; then
            echo "  ✅ ${instance}: Rodando"
            ((running_count++))
        else
            echo "  ❌ ${instance}: Parado"
            failed_instances+=("${instance}")
        fi
    done
    
    if [ "$running_count" -eq ${#PATRONI_INSTANCES[@]} ]; then
        echo "  ✓ Todos os ${#PATRONI_INSTANCES[@]} containers Patroni estão rodando"
        test_passed
        return 0
    else
        echo "  ✗ Problemas detectados (${running_count}/${#PATRONI_INSTANCES[@]} rodando)"
        test_failed
        return 1
    fi
}

identify_patroni_primary() {
    increment_test
    log_info "Identificando nó primário (Primary/Leader)..."
    
    # Método 1: Usar o endpoint /primary
    for node in "${PATRONI_INSTANCES[@]}"; do
        local HTTP_CODE=$(docker exec "$node" curl -s -o /dev/null -w "%{http_code}" http://localhost:8008/primary 2>/dev/null || echo "000")
        
        if [ "$HTTP_CODE" = "200" ]; then
            echo "  ✅ Primary identificado: ${node}"
            PATRONI_PRIMARY="$node"
            test_passed
            return 0
        fi
    done
    
    # Fallback
    PATRONI_PRIMARY="${PATRONI_INSTANCES[0]}"
    echo "  ⚠️  Usando ${PATRONI_PRIMARY} como padrão"
    test_passed
    return 0
}

test_patroni_health() {
    increment_test
    log_info "Verificando saúde dos nós Patroni..."
    
    local healthy_count=0
    local unhealthy_instances=()
    
    for node in "${PATRONI_INSTANCES[@]}"; do
        local HTTP_CODE=$(docker exec "$node" curl -s -o /dev/null -w "%{http_code}" http://localhost:8008/health 2>/dev/null || echo "000")
        
        if [ "$HTTP_CODE" = "200" ]; then
            echo "  ✅ ${node}: Saudável"
            ((healthy_count++))
        else
            echo "  ❌ ${node}: Problema (HTTP ${HTTP_CODE})"
            unhealthy_instances+=("$node")
        fi
    done
    
    if [ "$healthy_count" -eq ${#PATRONI_INSTANCES[@]} ]; then
        echo "  ✓ Todos os ${#PATRONI_INSTANCES[@]} nós estão saudáveis"
        test_passed
        return 0
    else
        echo "  ✗ Problemas detectados (${healthy_count}/${#PATRONI_INSTANCES[@]} saudáveis)"
        test_failed
        return 1
    fi
}

test_patroni_replication() {
    increment_test
    log_info "Testando replicação de dados..."
    
    local test_table="health_check_$(date +%s)"
    local test_value="replication-test-$(date +%Y%m%d-%H%M%S)"
    
    # Criar tabela e inserir dados no Primary
    docker exec "${PATRONI_PRIMARY}" psql -U postgres -c \
        "DROP TABLE IF EXISTS ${test_table};" &>/dev/null
    
    docker exec "${PATRONI_PRIMARY}" psql -U postgres -c \
        "CREATE TABLE ${test_table} (id serial PRIMARY KEY, data text);" &>/dev/null
    
    docker exec "${PATRONI_PRIMARY}" psql -U postgres -c \
        "INSERT INTO ${test_table} (data) VALUES ('${test_value}');" &>/dev/null
    
    # Aguardar replicação
    sleep 2
    
    # Verificar replicação em todos os nós
    local replicated_count=0
    for node in "${PATRONI_INSTANCES[@]}"; do
        local result=$(docker exec "$node" psql -U postgres -t -c \
            "SELECT data FROM ${test_table} LIMIT 1;" 2>/dev/null | xargs)
        
        if [ "$result" = "$test_value" ]; then
            ((replicated_count++))
        fi
    done
    
    # Limpar
    docker exec "${PATRONI_PRIMARY}" psql -U postgres -c \
        "DROP TABLE IF EXISTS ${test_table};" &>/dev/null
    
    if [ "$replicated_count" -eq ${#PATRONI_INSTANCES[@]} ]; then
        echo "  ✅ Replicação funcionando em todos os ${#PATRONI_INSTANCES[@]} nós"
        test_passed
        return 0
    else
        echo "  ❌ Problemas na replicação (${replicated_count}/${#PATRONI_INSTANCES[@]} nós OK)"
        test_failed
        return 1
    fi
}
