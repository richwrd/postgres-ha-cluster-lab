#!/bin/bash
# Script de pós-bootstrap do Patroni
# Autor: Eduardo Richard

set -e

echo "🔧 Executando configuração pós-bootstrap do cluster..."

# Carregar senhas do ambiente
HEALTHCHECK_PASS="${PGPOOL_HEALTHCHECK_PASSWORD:-default_password_change_me}"
TEST_USERNAME="${TEST_DB_USERNAME}"
TEST_PASSWORD="${TEST_DB_PASSWORD}"

echo "👤 Criando usuário healthchecker para Pgpool..."

psql -U postgres <<-EOSQL
  -- Criar o usuário com senha
  CREATE USER healthchecker WITH LOGIN PASSWORD '${HEALTHCHECK_PASS}';
  
  -- Permitir conectar no banco postgres
  GRANT CONNECT ON DATABASE postgres TO healthchecker;
  
  -- Permitir uso do schema public
  GRANT USAGE ON SCHEMA public TO healthchecker;
  
  -- Permissão de leitura em todas as tabelas existentes
  GRANT SELECT ON ALL TABLES IN SCHEMA public TO healthchecker;
  
  -- Permissões para futuras tabelas
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO healthchecker;
  
  -- Adicionar ao grupo pg_monitor (necessário para Pgpool 4.1+)
  GRANT pg_monitor TO healthchecker;
EOSQL

echo "✅ Usuário healthchecker criado com sucesso!"

# Criar usuário de teste se as variáveis estiverem definidas
if [ -n "${TEST_USERNAME}" ] && [ -n "${TEST_PASSWORD}" ]; then
  echo "👤 Criando usuário de teste ${TEST_USERNAME}..."
  
  psql -U postgres <<-EOSQL
    -- Criar o usuário de teste
    CREATE USER ${TEST_USERNAME} WITH LOGIN PASSWORD '${TEST_PASSWORD}';
    
    -- Garantir todas as permissões no banco postgres
    GRANT ALL PRIVILEGES ON DATABASE postgres TO ${TEST_USERNAME};
EOSQL

  psql -U postgres -d postgres <<-EOSQL
    -- Garantir todas as permissões no schema public
    GRANT ALL ON SCHEMA public TO ${TEST_USERNAME};
    
    -- Permitir criação de objetos
    GRANT CREATE ON SCHEMA public TO ${TEST_USERNAME};
    
    -- Permissões padrão para futuras tabelas
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${TEST_USERNAME};
EOSQL

  echo "✅ Usuário ${TEST_USERNAME} criado com sucesso!"
fi

echo ""
echo "Usuários do cluster:"
psql -U postgres -c "\du"

exit 0
