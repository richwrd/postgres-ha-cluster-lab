#!/bin/bash
# Script para testar cluster ETCD
# Autor: Eduardo Richard

echo "🔍 Testando Cluster ETCD"
echo "========================"

# Verificar se containers estão rodando
echo ""
echo "📋 Status dos containers:"
docker compose -f docker-compose.etcd.yaml ps

# Verificar saúde
echo ""
echo "💚 Verificando saúde do cluster:"
docker exec etcd-1 etcdctl endpoint health \
  --endpoints=http://etcd-1:2379,http://etcd-2:2379,http://etcd-3:2379

# Status detalhado
echo ""
echo "📊 Status detalhado do cluster:"
docker exec etcd-1 etcdctl endpoint status \
  --endpoints=http://etcd-1:2379,http://etcd-2:2379,http://etcd-3:2379 \
  -w table

# Listar membros
echo ""
echo "👥 Membros do cluster:"
docker exec etcd-1 etcdctl member list -w table

# Testar escrita e leitura
echo ""
echo "✍️  Testando escrita e leitura..."
docker exec etcd-1 etcdctl put /test/key "cluster-funcionando"
RESULT=$(docker exec etcd-1 etcdctl get /test/key --print-value-only)

if [ "$RESULT" = "cluster-funcionando" ]; then
  echo "✅ Teste de escrita/leitura: OK"
else
  echo "❌ Teste de escrita/leitura: FALHOU"
fi

# Testar consistência entre nós
echo ""
echo "🔄 Testando consistência entre nós..."
docker exec etcd-2 etcdctl get /test/key --print-value-only
docker exec etcd-3 etcdctl get /test/key --print-value-only
echo "✅ Dados consistentes em todos os nós"

# Limpar dados de teste
docker exec etcd-1 etcdctl del /test/key > /dev/null

echo ""
echo "✅ Todos os testes concluídos!"
echo "========================"