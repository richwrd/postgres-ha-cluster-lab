#!/bin/bash
# ==============================================================================
# Script: add_user.sh
# Descrição: Adiciona um novo usuário ao cluster PostgreSQL + PgPool
# Autor: Eduardo Richard
# ==============================================================================

set -e

# Carrega funções de logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/logging.sh"

# ==============================================================================
# Variáveis Globais
# ==============================================================================

USUARIO=""
SENHA=""
DATABASE="postgres"
LEADER_CONTAINER="${LEADER_CONTAINER:-patroni-postgres-3}"
PGPOOL_CONTAINER="${PGPOOL_CONTAINER:-pgpool}"

# ==============================================================================
# Funções de Validação
# ==============================================================================

# Exibe a mensagem de uso do script
show_usage() {
  log_error "Uso: $0 <usuario> <senha> [database]"
  echo ""
  echo "Exemplos:"
  echo "  $0 richard minha_senha"
  echo "  $0 app_user senha123 meu_banco"
  echo ""
  echo "Variáveis de ambiente opcionais:"
  echo "  LEADER_CONTAINER  - Nome do container líder do Patroni (padrão: patroni-postgres-3)"
  echo "  PGPOOL_CONTAINER  - Nome do container do PgPool (padrão: pgpool)"
}

# Valida e parse dos argumentos da linha de comando
parse_arguments() {
  USUARIO=$1
  SENHA=$2
  DATABASE=${3:-postgres}

  if [ -z "$USUARIO" ] || [ -z "$SENHA" ]; then
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
  log_info "Verificando containers..."
  
  check_container_running "${LEADER_CONTAINER}" || exit 1
  check_container_running "${PGPOOL_CONTAINER}" || exit 1
  
  log_success "Containers encontrados"
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
  # Parse e validação de argumentos
  parse_arguments "$@"
  
  # Executa o processo de adição
  add_user_to_cluster
}

# Executa apenas se o script for chamado diretamente (não sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
