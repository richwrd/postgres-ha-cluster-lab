#!/bin/bash
#
# Script para executar testes de performance do cluster
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(cd "$SCRIPT_DIR/../docker" && pwd)"
PYTEST_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CLUSTER_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VENV_DIR="$PYTEST_DIR/.venv"

echo "======================================================================"
echo "TESTE DE PERFORMANCE - CLUSTER COM PGPOOL"
echo "======================================================================"

# Função de cleanup
cleanup() {
    echo ""
    echo "🧹 Limpando ambiente..."
    cd "$DOCKER_DIR"
    docker compose -f docker-compose.pgbench-cluster.yaml down 2>/dev/null || true
    cd "$CLUSTER_ROOT"
    docker compose down 2>/dev/null || true
}

# Registra cleanup no exit
trap cleanup EXIT

# 1. Sobe o cluster completo (ETCD + Patroni + PgPool)
echo ""
echo "📦 [1/4] Subindo cluster PostgreSQL HA (ETCD + Patroni + PgPool)..."
cd "$CLUSTER_ROOT"
docker compose up -d

echo "⏳ Aguardando ETCD ficar saudável..."
sleep 10

echo "⏳ Aguardando cluster Patroni ficar saudável..."
timeout=120
elapsed=0
while [ $elapsed -lt $timeout ]; do
    # Verifica se pelo menos um nó Patroni está rodando
    if docker exec patroni1 patronictl list 2>/dev/null | grep -q "running"; then
        echo "✓ Cluster Patroni está rodando!"
        break
    fi
    sleep 5
    elapsed=$((elapsed + 5))
    echo -n "."
done

if [ $elapsed -ge $timeout ]; then
    echo "❌ Timeout aguardando cluster Patroni"
    exit 1
fi

echo "⏳ Aguardando PgPool ficar saudável..."
sleep 10
if docker exec pgpool pg_isready -h localhost -p 5432 -U postgres >/dev/null 2>&1; then
    echo "✓ PgPool está pronto!"
else
    echo "⚠️  PgPool pode não estar completamente pronto, mas continuando..."
fi

echo ""
echo "📦 [2/4] Subindo pgbench-client..."
cd "$DOCKER_DIR"
docker compose -f docker-compose.pgbench-cluster.yaml up -d

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
    pytest tests/performance/test_cluster_with_pgpool.py -v -s
    
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
