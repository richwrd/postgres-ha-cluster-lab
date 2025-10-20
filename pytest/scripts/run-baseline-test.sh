#!/bin/bash
#
# Script para executar testes de performance baseline
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "======================================================================"
echo "TESTE DE PERFORMANCE - BASELINE"
echo "======================================================================"

# Função de cleanup
cleanup() {
    echo ""
    echo "🧹 Limpando ambiente..."
    cd "$PROJECT_ROOT"
    docker-compose -f docker-compose.baseline.yaml down -v 2>/dev/null || true
    cd "$SCRIPT_DIR"
    docker-compose -f docker-compose.pgbench.yaml down 2>/dev/null || true
}

# Registra cleanup no exit
trap cleanup EXIT

# 1. Sobe o PostgreSQL baseline
echo ""
echo "📦 [1/3] Subindo PostgreSQL baseline..."
cd "$PROJECT_ROOT"
docker-compose -f docker-compose.baseline.yaml up -d

echo "⏳ Aguardando PostgreSQL ficar saudável..."
timeout=60
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if docker exec postgres-baseline pg_isready -U postgres >/dev/null 2>&1; then
        echo "✓ PostgreSQL está pronto!"
        break
    fi
    sleep 2
    elapsed=$((elapsed + 2))
    echo -n "."
done

if [ $elapsed -ge $timeout ]; then
    echo "❌ Timeout aguardando PostgreSQL"
    exit 1
fi

# 2. Sobe o container pgbench-client
echo ""
echo "📦 [2/3] Subindo container pgbench-client..."
cd "$SCRIPT_DIR"
docker-compose -f docker-compose.pgbench.yaml up -d

echo "⏳ Aguardando pgbench-client ficar pronto..."
sleep 5
if docker exec pgbench-client pg_isready --version >/dev/null 2>&1; then
    echo "✓ pgbench-client está pronto!"
else
    echo "❌ Erro ao iniciar pgbench-client"
    exit 1
fi

# 3. Executa os testes
echo ""
echo "🧪 [3/3] Executando testes de performance..."
cd "$PROJECT_ROOT/pytest"
pytest tests/performance/test_baseline_single_node.py -v -s

echo ""
echo "======================================================================"
echo "✅ TESTES CONCLUÍDOS COM SUCESSO!"
echo "======================================================================"
