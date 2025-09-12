#!/bin/bash
# ------------------------------------------------------------------------------------
# SCRIPT PRINCIPAL: follow_primary.sh
# Propósito: Gerencia a reconfiguração pós-failover usando módulos especializados
# Acionado após um failover bem-sucedido
# ------------------------------------------------------------------------------------
set -e pipefail

# --- Importações ---
# Importar configurações centralizadas primeiro
. "/opt/pgpool/bin/scripts/lib/env.sh"
. "/opt/pgpool/bin/scripts/lib/logging.sh"

# --- Parâmetros do Pgpool-II ---
FAILED_NODE_ID="$1"
OLD_PRIMARY_HOST="$2"
NEW_PRIMARY_HOST="$3"

# --- Função Principal ---
main() {
    local start_time
    start_time=$(get_timestamp)
    
    log_start "RECONFIGURAÇÃO PÓS-FAILOVER (FOLLOW PRIMARY)"
    log_metric "Evento recebido do Pgpool-II. Primário antigo: ${OLD_PRIMARY_HOST} (ID: ${FAILED_NODE_ID}). Novo primário: ${NEW_PRIMARY_HOST}."
    
    # Em um ambiente com Patroni, a sincronização das réplicas é gerenciada automaticamente
    log_metric "Nenhuma ação ativa necessária. O Patroni gerencia a sincronização das réplicas."
    
    # Aqui você pode adicionar validações adicionais se necessário:
    # - Verificar se as réplicas estão sincronizando corretamente
    # - Validar conectividade com o novo primário
    # - Enviar notificações para sistemas de monitoramento
    
    log_success "Reconfiguração pós-failover concluída com sucesso."
    log_end "RECONFIGURAÇÃO PÓS-FAILOVER (FOLLOW PRIMARY)" "$start_time"
}

# --- Validação de Parâmetros ---
if [ -z "$FAILED_NODE_ID" ] || [ -z "$OLD_PRIMARY_HOST" ] || [ -z "$NEW_PRIMARY_HOST" ]; then
    log_critical "Parâmetros obrigatórios não fornecidos: FAILED_NODE_ID, OLD_PRIMARY_HOST e NEW_PRIMARY_HOST"
    exit 1
fi

# --- Execução ---
main
