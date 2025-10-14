#!/bin/bash
# Script de pós-bootstrap do Patroni
# Autor: Eduardo Richard

set -e

echo "🔧 Executando configuração pós-bootstrap do cluster..."

# Carregar senha do ambiente
HEALTHCHECK_PASS="${PGPOOL_HEALTHCHECK_PASSWORD:-default_password_change_me}"

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
echo ""
echo "Usuários do cluster:"
psql -U postgres -c "\du healthchecker"

exit 0
