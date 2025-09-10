#!/bin/sh
# ------------------------------------------------------------------------------------
# HELPER SCRIPT: generate-backend-config.sh
# Propósito: Recebe o JSON do cluster Patroni via entrada padrão (stdin) e o
#            transforma na sintaxe de configuração de backend do pgpool.conf,
#            aplicando as melhores práticas para balanceamento de carga e failover.
# ------------------------------------------------------------------------------------
set -e


# O 'jq' lê da entrada padrão (que será o pipe do script principal)
jq -r '
  # PRIMEIRO: Verifica se a entrada é um objeto JSON válido com a chave "members"
  if type == "object" and has("members") then
    .members | .[] |
    # Ignora nós que não estejam em estado "running"
    if .state != "running" then empty else
      # SEGUNDO: Gera um ARRAY de strings [...] para cada nó. Esta é a correção principal.
      [
        "# Config for node: " + .name + " (" + .role + " at " + .host + ")",
        "backend_hostname" + (.state|split("")[0]) + " = \u0027" + .host + "\u0027",
        "backend_port" + (.state|split("")[0]) + " = " + (.port|tostring),
        "backend_weight" + (.state|split("")[0]) + " = 1",
        if .role == "leader" then
          "backend_flag" + (.state|split("")[0]) + " = \u0027ALWAYS_PRIMARY\u0027"
        else
          "backend_flag" + (.state|split("")[0]) + " = \u0027ALLOW_TO_FAILOVER\u0027"
        end
      ] | join("\n") # O filtro join("\n") agora opera sobre um array válido.
    end
  else
    # Se a entrada não for o JSON esperado, imprime uma mensagem de erro e sai.
    "ERRO: A entrada para jq não é um JSON válido do Patroni." | halt_error(1)
  end
' | sed 's/^backend/\nbackend/' | sed '1s/^\n//'