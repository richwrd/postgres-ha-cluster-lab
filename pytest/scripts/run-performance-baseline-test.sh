#!/bin/bash
#
# Script para executar testes de performance baseline
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(cd "$SCRIPT_DIR/../docker" && pwd)"
PYTEST_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_DIR="$PYTEST_DIR/.venv"

echo "======================================================================"
echo "TESTE DE PERFORMANCE - BASELINE"
echo "======================================================================"

# Função de cleanup
cleanup() {
    echo ""
    echo "🧹 Limpando ambiente..."
    cd "$DOCKER_DIR"
    docker compose -f docker-compose.pgbench-baseline.yaml down 2>/dev/null || true
    docker compose -f docker-compose.baseline.yaml down 2>/dev/null || true
}

# Registra cleanup no exit
trap cleanup EXIT

# 1. Sobe o ambiente baseline (PostgreSQL + pgbench-client)
echo ""
echo "📦 [1/4] Subindo PostgreSQL baseline..."
cd "$DOCKER_DIR"
docker compose -f docker-compose.baseline.yaml up -d

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

echo ""
echo "📦 [2/4] Subindo pgbench-client..."
docker compose -f docker-compose.pgbench-baseline.yaml up -d

echo "⏳ Aguardando pgbench-client ficar pronto..."
sleep 5
if docker exec pgbench-client pg_isready --version >/dev/null 2>&1; then
    echo "✓ pgbench-client está pronto!"
else
    echo "❌ Erro ao iniciar pgbench-client"
    exit 1
fi

# 3. Ativa o venv
echo ""
echo "🐍 [3/4] Ativando ambiente virtual Python..."
if [ ! -d "$VENV_DIR" ]; then
    echo "❌ Virtual environment não encontrado em $VENV_DIR"
    echo "💡 Execute: python3 -m venv $VENV_DIR && source $VENV_DIR/bin/activate && pip install -r requirements.txt"
    exit 1
fi

source "$VENV_DIR/bin/activate"
echo "✓ Virtual environment ativado!"

# 4. Executa os testes 3 vezes
echo ""
echo "🧪 [4/4] Executando testes de performance (3 iterações)..."
cd "$PYTEST_DIR"

for i in {1..3}; do
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔄 ITERAÇÃO $i/3"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    pytest tests/performance/test_baseline_single_node.py -v -s
    
    if [ $? -ne 0 ]; then
        echo "❌ Falha na iteração $i"
        exit 1
    fi
    
    if [ $i -lt 3 ]; then
        echo ""
        echo "⏸️  Aguardando 5 segundos antes da próxima iteração..."
        sleep 5
    fi
done

echo ""
echo "======================================================================"
echo "✅ TESTES CONCLUÍDOS COM SUCESSO! (3/3 iterações)"
echo "======================================================================"
