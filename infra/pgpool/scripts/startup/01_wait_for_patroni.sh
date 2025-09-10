#!/bin/sh
# ------------------------------------------------------------------------------------
# SCRIPT: 01-wait-for-patroni.sh
# Propósito: Aguarda até que pelo menos um nó do cluster Patroni esteja acessível.
# ------------------------------------------------------------------------------------
set -e

HELPER_SCRIPT="/opt/pgpool/bin/scripts/helpers/find_active_patroni_endpoint.sh"

echo "⏳ Aguardando a API de qualquer nó do Patroni ficar disponível..."

# Chama o script helper em loop. O '>/dev/null' descarta a saída de sucesso,
# pois só nos importamos se o script sai com código 0 (sucesso) ou não.
while ! sh "${HELPER_SCRIPT}" >/dev/null; do
  echo "Nenhum nó do Patroni respondeu. Tentando novamente em 5 segundos..."
  sleep 5
done

echo "✅ Pelo menos um endpoint do Patroni está online."