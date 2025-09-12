#!/bin/sh
# ------------------------------------------------------------------------------------
# BIBLIOTECA: patroni_operations.sh
# Propósito: Centraliza TODAS as operações relacionadas ao Patroni
# Inclui funcionalidade consolidada do antigo find_active_patroni_endpoint.sh
# ------------------------------------------------------------------------------------

# Importar logging
. /opt/pgpool/bin/scripts/lib/logging.sh

# --- Função para Encontrar Endpoint Ativo do Patroni (consolidada) ---
find_active_patroni_endpoint() {
    log_metric "Procurando um endpoint da API do Patroni para obter o estado do cluster..." >&2
    
    # Verificar se PATRONI_API_ENDPOINTS está definido
    if [ -z "$PATRONI_API_ENDPOINTS" ]; then
        log_critical "PATRONI_API_ENDPOINTS não está definido." >&2
        return 1
    fi
    
    # Percorrer todos os endpoints disponíveis
    for endpoint in $PATRONI_API_ENDPOINTS; do
        log_metric "Testando endpoint: ${endpoint}" >&2
        
        if curl --connect-timeout 3 -s -o /dev/null -w "%{http_code}" "${endpoint}/cluster" | grep -q "200"; then
            log_metric "API do Patroni encontrada em: ${endpoint}" >&2
            echo "$endpoint"
            return 0
        fi
    done
    
    # Se chegou até aqui, nenhum endpoint respondeu
    log_critical "Nenhum endpoint da API do Patroni respondeu." >&2
    return 1
}

# --- Função para Descobrir o Novo Líder ---
get_new_primary_host() {
    local patroni_endpoint="$1"
    
    if [ -z "$patroni_endpoint" ]; then
        log_error "Endpoint do Patroni não fornecido para get_new_primary_host"
        return 1
    fi
    
    log_metric "Consultando a API para identificar o novo líder..."
    
    local new_primary_host
    new_primary_host=$(curl -s "${patroni_endpoint}/cluster" | jq -r '.members[] | select(.role == "leader") | .host')
    
    if [ -z "$new_primary_host" ]; then
        log_critical "Não foi possível identificar um novo líder no cluster Patroni. Verifique o estado do Patroni."
        return 1
    fi
    
    log_metric "Patroni informa que o novo líder é: ${new_primary_host}"
    echo "$new_primary_host"
    return 0
}

# --- Função para Validar Estado do Cluster ---
validate_patroni_cluster() {
    local patroni_endpoint="$1"
    
    log_metric "Validando estado do cluster Patroni..."
    
    local cluster_info
    cluster_info=$(curl -s "${patroni_endpoint}/cluster" 2>/dev/null)
    
    if [ -z "$cluster_info" ]; then
        log_error "Não foi possível obter informações do cluster Patroni"
        return 1
    fi
    
    # Verificar se há um líder
    local leader_count
    leader_count=$(echo "$cluster_info" | jq -r '.members[] | select(.role == "leader")' | wc -l)
    
    if [ "$leader_count" -eq 0 ]; then
        log_warning "Nenhum líder encontrado no cluster Patroni"
        return 1
    elif [ "$leader_count" -gt 1 ]; then
        log_warning "Múltiplos líderes detectados no cluster Patroni (split-brain?)"
        return 1
    fi
    
    log_success "Cluster Patroni validado com sucesso"
    return 0
}
