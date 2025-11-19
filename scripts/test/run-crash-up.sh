#!/bin/bash

# ==============================================================================
# SCRIPT DE TESTE DE RTO (RECOVERY TIME OBJECTIVE) - FALHA DO NÓ PRIMÁRIO
# ==============================================================================

# Cenário: Teste de RTO - Falha Completa do Nó Primário
TEST_PY_FILE="pytest/tests/resilience/test_rto_primary_failure.py"
TEST_FUNCTION_PATH="TestRTOPrimaryFailure::test_primary_node_complete_failure[False]"

# --- EXECUÇÃO ---

echo "Executando teste de RTO - Falha do Nó Primário"
echo "-----------------------------------------------------"

# Ativar ambiente virtual se existir
if [ -d "./pytest/.venv" ]; then
  source ./pytest/.venv/bin/activate
fi

# Executar o teste pytest
TEST_TARGET="${TEST_PY_FILE}::${TEST_FUNCTION_PATH}"
pytest "$TEST_TARGET" -v -s

echo ""
echo "Teste concluído."
