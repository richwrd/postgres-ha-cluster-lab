#!/bin/sh
# ------------------------------------------------------------------------------------
# BIBLIOTECA: config_generator.sh
# Propósito: Centraliza funções para geração de configurações do Pgpool-II
# Inclui funcionalidade consolidada do antigo generate_backend_config.sh
# ------------------------------------------------------------------------------------

# Importar logging
. "/opt/pgpool/bin/scripts/lib/logging.sh"

# --- Função para Gerar Configuração de Backend ---
generate_backend_config() {
    log_metric "Gerando configuração de backend do Pgpool-II..." >&2
    
    # O 'jq' lê da entrada padrão (que será o pipe do script principal)
    jq -r '
      if type == "object" and has("members") then
        .members | to_entries | .[] |
        
        # Considera nós em "running" (líder) ou "streaming" (réplica saudável) como válidos
        if (.value.state == "running" or .value.state == "streaming") then
          [
            "# Config for node " + (.key|tostring) + ": " + .value.name + " (" + .value.role + " / state: " + .value.state + ")",
            "backend_hostname" + (.key|tostring) + " = " + .value.host,
            "backend_port" + (.key|tostring) + " = " + (.value.port|tostring),
            "backend_weight" + (.key|tostring) + " = " + (if .value.role == "leader" then "0.8" else "1" end), # Peso 0 para líder (não recebe conexões de leitura)
            "backend_data_directory" + (.key|tostring) + " = \u0027/var/lib/postgresql/data\u0027",
            "backend_flag" + (.key|tostring) + " = ALLOW_TO_FAILOVER",
            "backend_application_name" + (.key|tostring) + " = " + .value.name,
            ""
          ] | join("\n")
        else
          empty
        end
      else
        empty
      end
    '
}

# --- Função para Validar Configuração Gerada ---
validate_backend_config() {
    local config_content="$1"
    
    if [ -z "$config_content" ]; then
        log_error "Configuração de backend vazia ou inválida"
        return 1
    fi
    
    # Verificar se há pelo menos um backend configurado
    local backend_count
    backend_count=$(echo "$config_content" | grep -c "backend_hostname" || true)
    
    if [ "$backend_count" -eq 0 ]; then
        log_error "Nenhum backend válido encontrado na configuração"
        return 1
    fi
    
    log_success "Configuração validada: ${backend_count} backends configurados"
    return 0
}

# --- Função para Obter Estado Completo do Cluster ---
get_cluster_state() {
    local patroni_endpoint="$1"
    
    if [ -z "$patroni_endpoint" ]; then
        log_error "Endpoint do Patroni não fornecido para get_cluster_state"
        return 1
    fi
    
    log_metric "Obtendo estado completo do cluster Patroni..."
    
    local cluster_state
    cluster_state=$(curl -s "${patroni_endpoint}/cluster" 2>/dev/null)
    
    if [ -z "$cluster_state" ]; then
        log_error "Falha ao obter estado do cluster Patroni"
        return 1
    fi
    
    echo "$cluster_state"
    return 0
}
