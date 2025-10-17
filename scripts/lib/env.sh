#!/bin/bash
# ------------------------------------------------------------------------------------
# BIBLIOTECA COMUM: env.sh
# Fornece funções para carregar variáveis de ambiente de forma centralizada
# Detecta automaticamente o diretório raiz do projeto independente de onde é chamado
# by: richwrd
# ------------------------------------------------------------------------------------

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Função para determinar o diretório raiz do projeto
# ═══════════════════════════════════════════════════════════════════

get_project_root() {
    local current_dir="$1"
    local max_depth=5
    local depth=0
    
    # Procura pelo arquivo .env subindo até 5 níveis
    while [ $depth -lt $max_depth ]; do
        if [ -f "${current_dir}/.env" ]; then
            echo "${current_dir}"
            return 0
        fi
        
        # Subir um nível
        current_dir="$(cd "${current_dir}/.." && pwd)"
        depth=$((depth + 1))
        
        # Se chegou na raiz do sistema, parar
        if [ "${current_dir}" = "/" ]; then
            break
        fi
    done
    
    return 1
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Função para carregar variáveis de ambiente
# ═══════════════════════════════════════════════════════════════════

load_env() {
    # Determinar o diretório do script que está chamando esta função
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    
    # Encontrar o diretório raiz do projeto
    PROJECT_ROOT=$(get_project_root "${script_dir}")
    
    if [ -z "${PROJECT_ROOT}" ]; then
        echo "ERRO: Não foi possível encontrar o diretório raiz do projeto (.env não encontrado)"
        return 1
    fi
    
    # Definir caminhos dos arquivos .env
    ENV_ROOT="${PROJECT_ROOT}/.env"
    ENV_PATRONI="${PROJECT_ROOT}/infra/patroni-postgres/config/.patroni.env"
    ENV_PGPOOL="${PROJECT_ROOT}/infra/pgpool/config/.pgpool.env"
    
    # Carregar .env da raiz (obrigatório)
    if [ -f "${ENV_ROOT}" ]; then
        source "${ENV_ROOT}"
        echo "✓ Variáveis carregadas de: ${ENV_ROOT}"
    else
        echo "ERRO: Arquivo .env não encontrado em ${ENV_ROOT}"
        return 1
    fi
    
    # Carregar .env do Patroni (opcional)
    if [ -f "${ENV_PATRONI}" ]; then
        source "${ENV_PATRONI}"
        echo "✓ Variáveis carregadas de: ${ENV_PATRONI}"
    fi
    
    # Carregar .env do PGPool (opcional)
    if [ -f "${ENV_PGPOOL}" ]; then
        source "${ENV_PGPOOL}"
        echo "✓ Variáveis carregadas de: ${ENV_PGPOOL}"
    fi
    
    # Exportar variáveis de caminho para uso em outros scripts
    export PROJECT_ROOT
    export ENV_ROOT
    export ENV_PATRONI
    export ENV_PGPOOL
    
    return 0
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Função para exibir informações de ambiente (debug)
# ═══════════════════════════════════════════════════════════════════

show_env_info() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  INFORMAÇÕES DE AMBIENTE"
    echo "═══════════════════════════════════════════════════════════════"
    echo "PROJECT_ROOT    : ${PROJECT_ROOT:-<não definido>}"
    echo "ENV_ROOT        : ${ENV_ROOT:-<não definido>}"
    echo "ENV_PATRONI     : ${ENV_PATRONI:-<não definido>}"
    echo "ENV_PGPOOL      : ${ENV_PGPOOL:-<não definido>}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Função genérica para validar variáveis de ambiente
# ═══════════════════════════════════════════════════════════════════
# Uso: validate_env_vars VAR1 VAR2 VAR3 ...
# Retorna: 0 se todas as variáveis estão definidas, 1 caso contrário
#
# Exemplos:
#   validate_env_vars DATA_BASE_PATH
#   validate_env_vars PG1_DATA_PATH PG2_DATA_PATH PG3_DATA_PATH
#   validate_env_vars DATA_BASE_PATH ETCD1_DATA_PATH ETCD2_DATA_PATH ETCD3_DATA_PATH \
#                     PG1_DATA_PATH PG2_DATA_PATH PG3_DATA_PATH PGPOOL_DATA_PATH
# ═══════════════════════════════════════════════════════════════════

validate_env_vars() {
    local has_error=0
    local undefined_vars=()
    
    # Verificar se pelo menos uma variável foi passada
    if [ $# -eq 0 ]; then
        echo "❌ Erro: Nenhuma variável foi especificada para validação."
        return 1
    fi
    
    # Iterar sobre todas as variáveis passadas como parâmetros
    for var in "$@"; do
        if [ -z "${!var}" ]; then
            undefined_vars+=("$var")
            has_error=1
        fi
    done
    
    # Exibir erros se houver variáveis indefinidas
    if [ $has_error -eq 1 ]; then
        echo "❌ Erro: As seguintes variáveis não estão definidas no arquivo .env:"
        for var in "${undefined_vars[@]}"; do
            echo "   - $var"
        done
        return 1
    fi
    
    return 0
}

# ═══════════════════════════════════════════════════════════════════
# ◉➔ Auto-executar load_env se este arquivo for importado
# ═══════════════════════════════════════════════════════════════════

# Nota: As variáveis serão carregadas automaticamente quando este arquivo
# for importado via 'source' em outro script
