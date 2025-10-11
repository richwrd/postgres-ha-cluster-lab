#!/bin/bash
# Script para criar diretórios de dados para os componentes do PostgreSQL HA Cluster
# por: richwrd

set -e

load_env_file() {
  if [ -f "../.env" ]; then
    source "../.env"
  else
    echo "❌ Erro: Arquivo .env não encontrado no diretório pai."
    exit 1
  fi
}

validate_env_vars() {
  for var in DATA_BASE_PATH ETCD1_DATA_PATH ETCD2_DATA_PATH ETCD3_DATA_PATH PG1_DATA_PATH PG2_DATA_PATH PG3_DATA_PATH PGPOOL_DATA_PATH; do
    if [ -z "${!var}" ]; then
      echo "❌ Erro: A variável $var não está definida no arquivo .env."
      exit 1
    fi
  done
}

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
  for dir in "$ETCD1_DATA_PATH" "$ETCD2_DATA_PATH" "$ETCD3_DATA_PATH" "$PG1_DATA_PATH" "$PG2_DATA_PATH" "$PG3_DATA_PATH" "$PGPOOL_DATA_PATH"; do
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
  chmod 700 "$ETCD1_DATA_PATH" "$ETCD2_DATA_PATH" "$ETCD3_DATA_PATH" "$PG1_DATA_PATH" "$PG2_DATA_PATH" "$PG3_DATA_PATH" "$PGPOOL_DATA_PATH"
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
  sudo chown -R 999:999 "$PG1_DATA_PATH"
  sudo chown -R 999:999 "$PG2_DATA_PATH"
  sudo chown -R 999:999 "$PG3_DATA_PATH"
  sudo chown -R 999:999 "$PGPOOL_DATA_PATH"
  echo "✅ - Propriedade definida com sucesso"
}

display_summary() {
  echo ""
  echo "📋 Resumo: Diretórios de dados criados com sucesso:"
  echo "✅ - ETCD 1: $ETCD1_DATA_PATH"
  echo "✅ - ETCD 2: $ETCD2_DATA_PATH"
  echo "✅ - ETCD 3: $ETCD3_DATA_PATH"
  echo "✅ - Postgres 1: $PG1_DATA_PATH"
  echo "✅ - Postgres 2: $PG2_DATA_PATH"
  echo "✅ - Postgres 3: $PG3_DATA_PATH"
  echo "✅ - Pgpool: $PGPOOL_DATA_PATH"
}

main() {
  load_env_file
  validate_env_vars
  create_base_directory
  create_component_directories
  set_directory_permissions
  set_etcd_ownership
  set_postgres_ownership
  display_summary
}

main

exit 0
