#!/bin/bash
# Script para criar diretórios de dados para os componentes do PostgreSQL HA Cluster
# por: richwrd

set -e

# Carregar biblioteca de ambiente
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/env.sh"

# ═══════════════════════════════════════════════════════════════════

create_base_directory() {
  echo ""
  echo "📂 Criando diretório base para o PostgreSQL HA Cluster..."
  if [ -d "$DATA_BASE_PATH" ]; then
    echo "✅ - Diretório base já existe: $DATA_BASE_PATH"
  else
    mkdir -p "$DATA_BASE_PATH"
    echo "✅ - Diretório base criado: $DATA_BASE_PATH"
  fi
}

create_component_directories() {
  echo ""
  echo "📂 Criando diretórios de dados para os componentes do PostgreSQL HA Cluster..."
  for dir in "$ETCD1_DATA_PATH" "$ETCD2_DATA_PATH" "$ETCD3_DATA_PATH" "$PATRONI1_DATA_PATH" "$PATRONI2_DATA_PATH" "$PATRONI3_DATA_PATH" "$PGPOOL_DATA_PATH"; do
    if [ -d "$dir" ]; then
      echo "✅ - Diretório já existe: $dir"
    else
      mkdir -p "$dir"
      echo "✅ - Diretório criado: $dir"
    fi
  done
}

set_directory_permissions() {
  echo ""
  echo "🔒 Definindo permissões seguras (700) para os diretórios de dados..."
  chmod 700 "$ETCD1_DATA_PATH" "$ETCD2_DATA_PATH" "$ETCD3_DATA_PATH" "$PATRONI1_DATA_PATH" "$PATRONI2_DATA_PATH" "$PATRONI3_DATA_PATH" "$PGPOOL_DATA_PATH"
  echo "✅ - Permissões definidas com sucesso"
}

set_etcd_ownership() {
  echo ""
  echo "👤 Definindo propriedade para os diretórios de dados do ETCD..."
  sudo chown -R $(id -u):$(id -g) "$ETCD1_DATA_PATH"
  sudo chown -R $(id -u):$(id -g) "$ETCD2_DATA_PATH"
  sudo chown -R $(id -u):$(id -g) "$ETCD3_DATA_PATH"
  echo "✅ - Propriedade ETCD definida com sucesso"
}

set_postgres_ownership() {
  echo ""
  echo "👤 Definindo propriedade (999:999) para os diretórios de dados do PostgreSQL..."
  sudo chown -R 999:999 "$PATRONI1_DATA_PATH"
  sudo chown -R 999:999 "$PATRONI2_DATA_PATH"
  sudo chown -R 999:999 "$PATRONI3_DATA_PATH"
  sudo chown -R 999:999 "$PGPOOL_DATA_PATH"
  echo "✅ - Propriedade definida com sucesso"
}

display_summary() {
  echo ""
  echo "📋 Resumo: Diretórios de dados criados com sucesso:"
  echo "✅ - ETCD 1: $ETCD1_DATA_PATH"
  echo "✅ - ETCD 2: $ETCD2_DATA_PATH"
  echo "✅ - ETCD 3: $ETCD3_DATA_PATH"
  echo "✅ - Postgres 1: $PATRONI1_DATA_PATH"
  echo "✅ - Postgres 2: $PATRONI2_DATA_PATH"
  echo "✅ - Postgres 3: $PATRONI3_DATA_PATH"
  echo "✅ - Pgpool: $PGPOOL_DATA_PATH"
}

main() {
  load_env
  validate_env_vars DATA_BASE_PATH ETCD1_DATA_PATH ETCD2_DATA_PATH ETCD3_DATA_PATH \
  PATRONI1_DATA_PATH PATRONI2_DATA_PATH PATRONI3_DATA_PATH PGPOOL_DATA_PATH
  create_base_directory
  create_component_directories
  set_directory_permissions
  set_etcd_ownership
  set_postgres_ownership
  display_summary
}

main

exit 0
