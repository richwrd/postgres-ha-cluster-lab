#!/bin/bash
# ==============================================================================
# Script: add_user.sh
# Descrição: Adiciona um novo usuário ao cluster PostgreSQL + PgPool
# Autor: Eduardo Richard
# ==============================================================================

set -e

# Carrega funções de logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/env.sh"
source "${SCRIPT_DIR}/lib/logging.sh"

# ==============================================================================
# Variáveis Globais
# ==============================================================================

USUARIO=""
SENHA=""
DATABASE="postgres"
LEADER_CONTAINER=""
PGPOOL_CONTAINER="${PGPOOL_NAME:-pgpool}"

# ==============================================================================
# Funções de Validação
# ==============================================================================

# Identifica o nó primário do cluster Patroni
identify_patroni_primary() {
  log_info "Identificando nó primário (Primary/Leader)..."
  
  # Verificar se PATRONI_API_ENDPOINTS está definido
  if [ -z "$PATRONI_API_ENDPOINTS" ]; then
    log_error "PATRONI_API_ENDPOINTS não está definido no ambiente"
    return 1
  fi
  
  # Tentar identificar o primary usando a API do Patroni
  for endpoint in $PATRONI_API_ENDPOINTS; do
    # Extrair o nome do container do endpoint (http://patroni-postgres-1:8008 -> patroni-postgres-1)
    local container_name=$(echo "$endpoint" | sed -E 's|http://([^:]+):.*|\1|')
    
    log_info "  Testando endpoint: ${endpoint} (container: ${container_name})"
    
    # Verificar se o container existe
    if ! docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
      log_warning "    Container '${container_name}' não encontrado ou não está rodando"
      continue
    fi
    
    # Método 1: Usar o endpoint /primary (retorna 200 apenas se for o primário)
    local HTTP_CODE=$(docker exec "$container_name" curl -s -o /dev/null -w "%{http_code}" http://localhost:8008/primary 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" = "200" ]; then
      log_success "  ✅ Primary identificado: ${container_name}"
      LEADER_CONTAINER="$container_name"
      return 0
    fi
  done
  
  # Fallback: Se nenhum primary foi identificado, tentar pegar o primeiro container disponível
  log_warning "  ⚠️  Não foi possível identificar o primary automaticamente"
  
  for endpoint in $PATRONI_API_ENDPOINTS; do
    local container_name=$(echo "$endpoint" | sed -E 's|http://([^:]+):.*|\1|')
    
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
      LEADER_CONTAINER="$container_name"
      log_warning "  ⚠️  Usando ${LEADER_CONTAINER} como fallback"
      return 0
    fi
  done
  
  log_error "Nenhum container Patroni disponível"
  return 1
}

# Exibe a mensagem de uso do script
show_usage() {
  log_error "Uso: $0 [usuario] [senha] [database]"
  echo ""
  echo "Se usuário e senha não forem fornecidos, serão usados os valores de:"
  echo "  TEST_DB_USERNAME e TEST_DB_PASSWORD (definidos no .env)"
  echo ""
  echo "Exemplos:"
  echo "  $0                              # Usa TEST_DB_USERNAME e TEST_DB_PASSWORD"
  echo "  $0 richard minha_senha          # Cria usuário 'richard'"
  echo "  $0 app_user senha123 meu_banco  # Cria usuário 'app_user' no banco 'meu_banco'"
  echo ""
  echo "Variáveis de ambiente:"
  echo "  PGPOOL_NAME              - Nome do container do PgPool (padrão: pgpool)"
  echo "  PATRONI_API_ENDPOINTS    - Endpoints da API do Patroni para identificar o leader"
  echo "  TEST_DB_USERNAME         - Usuário padrão se não for especificado"
  echo "  TEST_DB_PASSWORD         - Senha padrão se não for especificada"
}

# Valida e parse dos argumentos da linha de comando
parse_arguments() {
  # Se argumentos foram passados, usar eles
  if [ $# -ge 2 ]; then
    USUARIO=$1
    SENHA=$2
    DATABASE=${3:-postgres}
  # Se não foram passados argumentos, usar variáveis de ambiente
  elif [ $# -eq 0 ]; then
    if [ -z "${TEST_DB_USERNAME}" ] || [ -z "${TEST_DB_PASSWORD}" ]; then
      log_error "Nenhum argumento fornecido e TEST_DB_USERNAME/TEST_DB_PASSWORD não estão definidos"
      show_usage
      exit 1
    fi
    
    USUARIO="${TEST_DB_USERNAME}"
    SENHA="${TEST_DB_PASSWORD}"
    DATABASE="postgres"
    
    log_info "Usando credenciais de ambiente: usuário='${USUARIO}', database='${DATABASE}'"
  else
    log_error "Argumentos inválidos: forneça usuário E senha, ou nenhum argumento"
    show_usage
    exit 1
  fi
}

# Verifica se um container está rodando
check_container_running() {
  local container=$1
  
  if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
    log_error "Container '${container}' não está rodando!"
    log_info "Containers disponíveis:"
    docker ps --format "  - {{.Names}}"
    return 1
  fi
  
  return 0
}

# Valida se todos os containers necessários estão rodando
validate_containers() {
  log_info "Validando ambiente e containers..."
  
  # 1. Identificar o nó primário do Patroni
  if ! identify_patroni_primary; then
    log_error "Falha ao identificar o nó primário do Patroni"
    exit 1
  fi
  
  # 2. Verificar se o container do PgPool está rodando
  if ! check_container_running "${PGPOOL_CONTAINER}"; then
    exit 1
  fi
  
  log_success "Ambiente validado: Leader='${LEADER_CONTAINER}', PgPool='${PGPOOL_CONTAINER}'"
}

# ==============================================================================
# Funções de Operação no PostgreSQL
# ==============================================================================

# Cria um usuário no PostgreSQL
create_postgres_user() {
  local username=$1
  local password=$2
  
  log_info "Criando usuário '${username}' no PostgreSQL (${LEADER_CONTAINER})..."
  
  if docker exec "${LEADER_CONTAINER}" psql -U postgres -c \
    "CREATE USER ${username} WITH PASSWORD '${password}';" 2>&1 | grep -v "already exists"; then
    log_success "Usuário criado no PostgreSQL"
    return 0
  else
    log_warning "Usuário já existe no PostgreSQL, continuando..."
    return 0
  fi
}

# Concede privilégios a um usuário em um database
grant_database_privileges() {
  local username=$1
  local database=$2
  
  log_info "Concedendo privilégios no database '${database}'..."
  
  docker exec "${LEADER_CONTAINER}" psql -U postgres -c \
    "GRANT ALL PRIVILEGES ON DATABASE ${database} TO ${username};" > /dev/null
  
  docker exec "${LEADER_CONTAINER}" psql -U postgres -d "${database}" -c \
    "GRANT ALL ON SCHEMA public TO ${username};" > /dev/null
  
  docker exec "${LEADER_CONTAINER}" psql -U postgres -d "${database}" -c \
    "GRANT CREATE ON SCHEMA public TO ${username};" > /dev/null
  
  docker exec "${LEADER_CONTAINER}" psql -U postgres -d "${database}" -c \
    "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${username};" > /dev/null
  
  log_success "Privilégios concedidos"
}

# ==============================================================================
# Funções de Operação no PgPool
# ==============================================================================

# Adiciona a senha de um usuário ao pool_passwd do PgPool
add_user_to_pool_passwd() {
  local username=$1
  local password=$2
  
  log_info "Adicionando senha ao pool_passwd do PgPool..."
  
  docker exec "${PGPOOL_CONTAINER}" sh -c \
    "pg_md5 -m -u ${username} ${password} >> /opt/pgpool/pool_passwd"
  
  log_success "Senha adicionada ao pool_passwd"
}

# Recarrega a configuração do PgPool sem reiniciar
reload_pgpool_config() {
  log_info "Recarregando configuração do PgPool..."
  
  docker exec "${PGPOOL_CONTAINER}" pgpool reload > /dev/null 2>&1
  
  log_success "PgPool recarregado"
}

# ==============================================================================
# Funções de Apresentação
# ==============================================================================

# Exibe mensagem de sucesso com instruções de teste
show_success_message() {
  local username=$1
  local database=$2
  local password=$3
  
  echo ""
  log_success "✅ Usuário '${username}' adicionado com sucesso ao cluster!"
  echo ""
  log_info "🧪 Teste a conexão com:"
  echo "   psql -h localhost -p 5433 -U ${username} -d ${database}"
  echo ""
  log_info "📋 Ou via DBeaver/outro cliente:"
  echo "   Host: localhost"
  echo "   Port: 5433"
  echo "   Database: ${database}"
  echo "   Username: ${username}"
  echo "   Password: ${password}"
}

# ==============================================================================
# Função Principal
# ==============================================================================

# Orquestra todo o processo de adição de usuário
add_user_to_cluster() {
  log_info "Adicionando usuário '${USUARIO}' ao cluster PostgreSQL"
  
  # 1. Validação
  validate_containers
  
  # 2. Operações no PostgreSQL
  create_postgres_user "${USUARIO}" "${SENHA}"
  grant_database_privileges "${USUARIO}" "${DATABASE}"
  
  # 3. Operações no PgPool
  add_user_to_pool_passwd "${USUARIO}" "${SENHA}"
  reload_pgpool_config
  
  # 4. Feedback final
  show_success_message "${USUARIO}" "${DATABASE}" "${SENHA}"
}

# ==============================================================================
# Execução Principal
# ==============================================================================

main() {
  load_env
  validate_env_vars PATRONI_API_ENDPOINTS TEST_DB_USERNAME TEST_DB_PASSWORD

  # Parse e validação de argumentos
  parse_arguments "$@"
  
  # Executa o processo de adição
  add_user_to_cluster
}

# Executa apenas se o script for chamado diretamente (não sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
