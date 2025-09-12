#!/bin/bash
# ------------------------------------------------------------------------------------
# SCRIPT PRINCIPAL: failover.sh
# Propósito: Orquestra o processo de failover usando módulos especializados
# Acionado quando o Pgpool-II detecta que o nó primário falhou
# ------------------------------------------------------------------------------------

# Torna o script robusto: sai em caso de erro e falha se um comando em um pipe falhar
set -eo pipefail

# --- Importações ---
# Importar configurações centralizadas primeiro
# O ponto (.) é um atalho para o comando 'source'
. "/opt/pgpool/bin/scripts/lib/env.sh"

. "${LIB_DIR}/logging.sh"
. "${LIB_DIR}/patroni_operations.sh"
. "${LIB_DIR}/pgpool_operations.sh"

# --- Parâmetros do Pgpool-II ---
FAILED_NODE_ID="$1"
FAILED_NODE_HOST="$2"

# --- Função Principal ---
main() {
    local start_time
    start_time=$(get_timestamp)
    
    log_start "PROCESSO DE FAILOVER"
    log_metric "ALERTA: Pgpool-II detectou falha no nó primário ID: ${FAILED_NODE_ID} (${FAILED_NODE_HOST})."
    
    # Etapa 1: Encontrar endpoint ativo do Patroni
    local active_endpoint
    if ! active_endpoint=$(find_active_patroni_endpoint); then
        log_critical "Falha ao encontrar endpoint do Patroni. Abortando failover."
        exit 1
    fi
    
    # Etapa 2: Validar estado do cluster
    if ! validate_patroni_cluster "$active_endpoint"; then
        log_warning "Cluster Patroni pode estar em estado inconsistente, mas continuando..."
    fi
    
    # Etapa 3: Descobrir o novo primário
    local new_primary_host
    if ! new_primary_host=$(get_new_primary_host "$active_endpoint"); then
        log_critical "Falha ao identificar novo líder. Abortando failover."
        exit 1
    fi
    
    # Etapa 4: Encontrar Node ID do novo primário no Pgpool-II
    local new_primary_node_id
    if ! new_primary_node_id=$(get_pgpool_node_id "$new_primary_host"); then
        log_critical "Falha ao encontrar Node ID no Pgpool-II. Abortando failover."
        exit 1
    fi
    
    # Etapa 5: Promover o novo nó primário no Pgpool-II
    if ! promote_pgpool_node "$new_primary_node_id" "$new_primary_host"; then
        log_error "Falha na promoção do nó, mas continuando para não bloquear o Pgpool-II."
    fi
    
    log_end "PROCESSO DE FAILOVER" "$start_time"
}

# --- Validação de Parâmetros ---
if [ -z "$FAILED_NODE_ID" ] || [ -z "$FAILED_NODE_HOST" ]; then
    log_critical "Parâmetros obrigatórios não fornecidos: FAILED_NODE_ID e FAILED_NODE_HOST"
    exit 1
fi

# --- Execução ---
main
