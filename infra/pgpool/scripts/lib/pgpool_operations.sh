#!/bin/sh
# ------------------------------------------------------------------------------------
# BIBLIOTECA: pgpool_operations.sh
# Propósito: Centraliza operações relacionadas ao Pgpool-II
# ------------------------------------------------------------------------------------

# Importar logging
. /opt/pgpool/bin/scripts/lib/logging.sh

# --- Função para Encontrar Node ID do Pgpool-II ---
get_pgpool_node_id() {
    local target_host="$1"
    
    if [ -z "$target_host" ]; then
        log_error "Host não fornecido para get_pgpool_node_id"
        return 1
    fi
    
    log_metric "Buscando o Node ID do Pgpool-II para o host ${target_host}..."
    
    local node_id
    node_id=$(/opt/pgpool/bin/pcp_node_info -h "$PCP_HOST" -p "$PCP_PORT" -U "$PCP_USER" -w --no-header | grep "${target_host}" | awk '{print $1}')
    
    if [ -z "$node_id" ]; then
        log_critical "Não foi possível encontrar o Node ID correspondente a ${target_host} no Pgpool-II."
        return 1
    fi
    
    log_metric "Host ${target_host} corresponde ao Node ID ${node_id} no Pgpool-II."
    echo "$node_id"
    return 0
}

# --- Função para Promover Nó no Pgpool-II ---
promote_pgpool_node() {
    local node_id="$1"
    local new_primary_host="$2"
    
    if [ -z "$node_id" ] || [ -z "$new_primary_host" ]; then
        log_error "Node ID ou host não fornecidos para promote_pgpool_node"
        return 1
    fi
    
    log_metric "Enviando comando para o Pgpool-II promover o Node ID ${node_id} a novo primário..."
    
    if /opt/pgpool/bin/pcp_promote_node -h "$PCP_HOST" -p "$PCP_PORT" -U "$PCP_USER" -w "${node_id}" >> "${LOG_FILE_FAILOVER}" 2>&1; then
        log_success "Pgpool-II agora considera ${new_primary_host} (ID: ${node_id}) como o novo primário."
        return 0
    else
        log_error "O comando pcp_promote_node falhou. Verifique os logs."
        return 1
    fi
}

# --- Função para Obter Status dos Nós ---
get_node_status() {
    local node_id="$1"
    
    log_metric "Obtendo status do nó ${node_id}..."
    
    local status
    status=$(/opt/pgpool/bin/pcp_node_info -h "$PCP_HOST" -p "$PCP_PORT" -U "$PCP_USER" -w "$node_id" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "$status"
        return 0
    else
        log_error "Falha ao obter status do nó ${node_id}"
        return 1
    fi
}

# --- Função para Listar Todos os Nós ---
list_all_nodes() {
    log_metric "Listando todos os nós do Pgpool-II..."
    
    local nodes_info
    nodes_info=$(/opt/pgpool/bin/pcp_node_info -h "$PCP_HOST" -p "$PCP_PORT" -U "$PCP_USER" -w --no-header 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "$nodes_info"
        return 0
    else
        log_error "Falha ao listar nós do Pgpool-II"
        return 1
    fi
}
