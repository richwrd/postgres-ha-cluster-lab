#!/bin/sh
set -e

# --- Importações ---
# Importar configurações centralizadas primeiro
. "/opt/pgpool/bin/scripts/lib/env.sh"

# Importar bibliotecas necessárias
. "${LIB_DIR}/logging.sh"
. "${LIB_DIR}/patroni_operations.sh"
. "${LIB_DIR}/config_generator.sh"

PGPOOL_CONFIG_FILE="/opt/pgpool/etc/pgpool.conf"
PGPOOL_CONFIG_TEMPLATE="/etc/pgpool2/pgpool.template.conf"

echo "⚙️  Iniciando geração da configuração do Pgpool-II..."

# ═══════════════════════════════════════════════════════════════════
# Etapa 1: Encontrar um endpoint ativo do Patroni
echo "Buscando um endpoint ativo do Patroni..."
ACTIVE_ENDPOINT=$(find_active_patroni_endpoint)
echo "✅ Usando o endpoint ativo: ${ACTIVE_ENDPOINT}"

# ═══════════════════════════════════════════════════════════════════
# Etapa 2: Obter os dados do cluster
echo "Buscando dados do cluster..."
CLUSTER_INFO=$(curl -s "${ACTIVE_ENDPOINT}/cluster")

# ═══════════════════════════════════════════════════════════════════
# Etapa 3: Gerar a configuração dos backends usando a biblioteca consolidada
echo "Processando dados do cluster para gerar configuração de backend..."
BACKEND_CONFIG=$(echo "$CLUSTER_INFO" | generate_backend_config)

if [ -z "$BACKEND_CONFIG" ]; then
  echo "🚨 Erro: A configuração de backend gerada está vazia."
  exit 1
fi

# ═══════════════════════════════════════════════════════════════════
# Etapa 4: Preencher o template com a configuração gerada
echo "Gerando o arquivo ${PGPOOL_CONFIG_FILE} a partir do template..."
# Usamos um método mais robusto para substituir, caso a variável tenha caracteres especiais
awk -v var="$BACKEND_CONFIG" '{gsub(/##BACKEND_NODES_CONFIG##/, var)}1' "${PGPOOL_CONFIG_TEMPLATE}" > "${PGPOOL_CONFIG_FILE}"

# ═══════════════════════════════════════════════════════════════════
# Etapa 5: Aplicar outras variáveis de ambiente para tuning
echo "Aplicando variáveis de ambiente de tuning..."
sed -i "s/num_init_children = .*/num_init_children = ${PGPOOL_NUM_INIT_CHILDREN:-32}/g" "${PGPOOL_CONFIG_FILE}"
sed -i "s/max_pool = .*/max_pool = ${PGPOOL_MAX_POOL:-100}/g" "${PGPOOL_CONFIG_FILE}"

echo "✅ Arquivo de configuração do Pgpool-II gerado com sucesso."
echo "Configuração de Backend Aplicada:"
echo "${BACKEND_CONFIG}"