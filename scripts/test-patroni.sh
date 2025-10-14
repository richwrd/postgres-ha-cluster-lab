#!/bin/bash
# Script para testar cluster Patroni PostgreSQL
# Autor: Eduardo Richard

set -e

# Variáveis globais
PRIMARY=""
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yaml}"

# ═══════════════════════════════════════════════════════════════════
# FUNÇÕES
# ═══════════════════════════════════════════════════════════════════

show_header() {
  echo "🔍 Testando Cluster Patroni PostgreSQL"
  echo "======================================="
}

check_containers_status() {
  echo ""
  echo "📋 Status dos containers:"
  docker compose -f "$COMPOSE_FILE" ps
}

list_cluster_members() {
  echo ""
  echo "👥 Listando membros do cluster:"
  docker exec patroni-postgres-1 patronictl list
}

identify_primary() {
  echo ""
  echo "👑 Identificando o líder (Primary):"
  
  # Método 1: Usar o endpoint /primary que retorna HTTP 200 apenas no líder
  for node in patroni-postgres-1 patroni-postgres-2 patroni-postgres-3; do
    HTTP_CODE=$(docker exec $node curl -s -o /dev/null -w "%{http_code}" http://localhost:8008/primary 2>/dev/null)
    
    if [ "$HTTP_CODE" = "200" ]; then
      echo "✅ $node é o LÍDER (Primary)"
      PRIMARY=$node
      break
    else
      echo "⚪ $node é Replica (HTTP $HTTP_CODE)"
    fi
  done
  
  # Fallback: usar patronictl para identificar
  if [ -z "$PRIMARY" ]; then
    echo "⚠️  Tentando identificar líder via patronictl..."
    PRIMARY=$(docker exec patroni-postgres-1 patronictl list -f json 2>/dev/null | \
              grep -o '"Role":"Leader".*"Member":"[^"]*"' | \
              grep -o 'patroni-postgres-[0-9]' | head -1)
    
    if [ -n "$PRIMARY" ]; then
      echo "✅ Líder identificado via patronictl: $PRIMARY"
    else
      PRIMARY="patroni-postgres-1"
      echo "⚠️  Usando $PRIMARY como padrão"
    fi
  fi
}

check_nodes_health() {
  echo ""
  echo "💚 Verificando saúde individual dos nós:"
  
  for node in patroni-postgres-1 patroni-postgres-2 patroni-postgres-3; do
    HTTP_CODE=$(docker exec $node curl -s -o /dev/null -w "%{http_code}" http://localhost:8008/health)
    
    if [ "$HTTP_CODE" = "200" ]; then
      echo "✅ $node: SAUDÁVEL (HTTP $HTTP_CODE)"
    else
      echo "❌ $node: PROBLEMA (HTTP $HTTP_CODE)"
    fi
  done
}

create_test_data() {
  echo ""
  echo "✍️  Testando replicação entre nós..."
  echo "📝 Criando tabela de teste no primary ($PRIMARY)..."
  
  docker exec $PRIMARY psql -U postgres -c "DROP TABLE IF EXISTS patroni_test;"
  docker exec $PRIMARY psql -U postgres -c \
    "CREATE TABLE patroni_test (
      id serial, 
      test_data text, 
      created_at timestamp default now()
    );"
  docker exec $PRIMARY psql -U postgres -c \
    "INSERT INTO patroni_test (test_data) VALUES ('replicacao-funcionando');"
  
  echo "⏳ Aguardando replicação (3 segundos)..."
  sleep 3
}

verify_replication() {
  echo ""
  echo "🔄 Verificando consistência dos dados em todos os nós:"
  
  for node in patroni-postgres-1 patroni-postgres-2 patroni-postgres-3; do
    RESULT=$(docker exec $node psql -U postgres -t -c \
      "SELECT test_data FROM patroni_test LIMIT 1;" 2>/dev/null | xargs)
    
    if [ "$RESULT" = "replicacao-funcionando" ]; then
      echo "✅ $node: Dados replicados corretamente"
    else
      echo "❌ $node: Falha na replicação"
    fi
  done
}

check_replication_lag() {
  echo ""
  echo "⏱️  Lag de replicação:"
  docker exec patroni-postgres-1 patronictl list | grep -E "Member|Lag|---"
}

verify_etcd_configuration() {
  echo ""
  echo "🔧 Verificando configuração do cluster no etcd:"
  
  KEYS=$(docker exec etcd-1 etcdctl get /service/ --prefix --keys-only 2>/dev/null | head -5)
  
  if [ -n "$KEYS" ]; then
    echo "$KEYS"
    echo "✅ Configuração encontrada no etcd"
  else
    echo "⚠️  Nenhuma chave encontrada no etcd"
  fi
}

cleanup_test_data() {
  echo ""
  echo "🧹 Limpando dados de teste..."
  docker exec $PRIMARY psql -U postgres -c \
    "DROP TABLE IF EXISTS patroni_test;" > /dev/null 2>&1
  echo "✅ Dados de teste removidos"
}

show_cluster_summary() {
  echo ""
  echo "📊 Resumo final do Cluster:"
  docker exec patroni-postgres-1 patronictl list
}

show_footer() {
  echo ""
  echo "✅ Todos os testes concluídos!"
  echo "======================================="
}

# ═══════════════════════════════════════════════════════════════════
# FUNÇÃO PRINCIPAL
# ═══════════════════════════════════════════════════════════════════

main() {
  show_header
  check_containers_status
  list_cluster_members
  identify_primary
  check_nodes_health
  create_test_data
  verify_replication
  check_replication_lag
  verify_etcd_configuration
  cleanup_test_data
  show_cluster_summary
  show_footer
}

# ═══════════════════════════════════════════════════════════════════
# EXECUÇÃO
# ═══════════════════════════════════════════════════════════════════

main

exit 0
