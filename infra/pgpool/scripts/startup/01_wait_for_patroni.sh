#!/bin/sh
# ------------------------------------------------------------------------------------
# SCRIPT: 01_wait_for_patroni.sh
# Propósito: Aguarda até que pelo menos um nó do cluster Patroni esteja acessível.
# ------------------------------------------------------------------------------------
set -e

# --- Importações ---
# Importar configurações centralizadas primeiro
. "/opt/pgpool/bin/scripts/lib/env.sh"

# Importar bibliotecas necessárias
. "${LIB_DIR}/logging.sh"
. "${LIB_DIR}/patroni_operations.sh"

echo "⏳ Aguardando a API de qualquer nó do Patroni ficar disponível..."

# Usar a função consolidada em loop
while ! find_active_patroni_endpoint >/dev/null 2>&1; do
  echo "Nenhum nó do Patroni respondeu. Tentando novamente em 5 segundos..."
  sleep 5
done

echo "✅ Pelo menos um endpoint do Patroni está online."