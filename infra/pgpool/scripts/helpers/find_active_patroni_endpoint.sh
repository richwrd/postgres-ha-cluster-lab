#!/bin/sh
# ------------------------------------------------------------------------------------
# HELPER SCRIPT: find-active-patroni-endpoint.sh
# Propósito: Percorre a lista de endpoints do Patroni definida em
#            PATRONI_API_ENDPOINTS. Retorna o primeiro endpoint que responder
#            com sucesso (HTTP 200) ao endpoint /cluster.
# Saída:
#   - Em caso de sucesso: Imprime a URL do endpoint ativo na saída padrão (stdout)
#     e sai com código 0.
#   - Em caso de falha: Imprime uma mensagem de erro na saída de erro (stderr)
#     e sai com código 1.
# ------------------------------------------------------------------------------------
set -e

for endpoint in ${PATRONI_API_ENDPOINTS}; do
  if curl --connect-timeout 3 -s -o /dev/null -w "%{http_code}" "${endpoint}/cluster" | grep -q "200"; then
    # Sucesso! Imprime o endpoint encontrado e sai.
    echo "${endpoint}"
    exit 0
  fi
done

# Se o loop terminar sem encontrar nenhum endpoint, falhamos.
echo "Erro: Nenhum endpoint do Patroni respondeu." >&2
exit 1