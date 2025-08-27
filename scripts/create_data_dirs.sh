#!/bin/bash
# Script to create data directories for PostgreSQL HA Cluster components
# by: richwrd

set -e

load_env_file() {
  if [ -f "../.env" ]; then
    source "../.env"
  else
    echo "Error: .env file not found in parent directory."
    exit 1
  fi
}

validate_env_vars() {
  for var in DATA_BASE_PATH ETCD_DATA_PATH PG1_DATA_PATH PG2_DATA_PATH PG3_DATA_PATH; do
    if [ -z "${!var}" ]; then
      echo "Error: $var is not defined in .env file."
      exit 1
    fi
  done
}

create_base_directory() {
  echo "Creating base data directory for PostgreSQL HA Cluster..."
  if [ -d "$DATA_BASE_PATH" ]; then
    echo "- Base directory already exists: $DATA_BASE_PATH"
  else
    mkdir -p "$DATA_BASE_PATH"
    echo "- Created base directory: $DATA_BASE_PATH"
  fi
}

create_component_directories() {
  echo "Creating data directories for PostgreSQL HA Cluster components..."
  for dir in "$ETCD_DATA_PATH" "$PG1_DATA_PATH" "$PG2_DATA_PATH" "$PG3_DATA_PATH"; do
    if [ -d "$dir" ]; then
      echo "- Directory already exists: $dir"
    else
      mkdir -p "$dir"
      echo "- Created directory: $dir"
    fi
  done
}

set_directory_permissions() {
  echo "Setting secure permissions (700) for data directories..."
  chmod 700 "$ETCD_DATA_PATH" "$PG1_DATA_PATH" "$PG2_DATA_PATH" "$PG3_DATA_PATH"
  echo "- Permissions set successfully"
}

set_postgres_ownership() {
  echo "Setting ownership (999:999) for PostgreSQL data directories..."
  sudo chown -R 999:999 "$PG1_DATA_PATH"
  sudo chown -R 999:999 "$PG2_DATA_PATH" 
  sudo chown -R 999:999 "$PG3_DATA_PATH"
  echo "- Ownership set successfully"
}

display_summary() {
  echo "Data directories created successfully:"
  echo "- ETCD: $ETCD_DATA_PATH"
  echo "- Postgres 1: $PG1_DATA_PATH"
  echo "- Postgres 2: $PG2_DATA_PATH" 
  echo "- Postgres 3: $PG3_DATA_PATH"
}

main() {
  load_env_file
  validate_env_vars
  create_base_directory
  create_component_directories
  set_directory_permissions
  set_postgres_ownership
  display_summary
}

main

exit 0