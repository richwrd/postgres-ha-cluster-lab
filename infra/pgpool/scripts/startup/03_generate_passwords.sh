#!/bin/sh
set -e

# Verifica se a variável HOME está definida para evitar erros
if [ -z "$HOME" ]; then
  echo "ERRO: A variável de ambiente HOME não está definida." >&2
  exit 1
fi

echo "🔑 Gerando arquivos de senha no diretório home do usuário ($HOME)..."

# ------------------------------------------------------------------------------------
# Arquivo: .pgpass
# Propósito: Usado pelo próprio serviço Pgpool-II para se conectar como um CLIENTE
#            aos nós do PostgreSQL (backends) e realizar checagens de saúde
#            (parâmetro 'health_check_user') e de replicação ('sr_check_user').
# ------------------------------------------------------------------------------------
echo "Gerando .pgpass para autenticação do Pgpool-II nos backends PostgreSQL..."
echo "*:*:*:${PGPOOL_HEALTHCHECK_USER}:${PGPOOL_HEALTHCHECK_PASSWORD}" > "${HOME}/.pgpass"
echo "*:*:*:${PGPOOL_SR_CHECK_USER}:${PGPOOL_SR_CHECK_PASSWORD}" >> "${HOME}/.pgpass"

# ------------------------------------------------------------------------------------
# Arquivo: .pcppass
# Propósito: Usado pelas ferramentas CLIENTE do PCP (ex: pcp_node_count no healthcheck
#            do Docker) para se conectar à porta de administração (9898) do Pgpool-II.
# ------------------------------------------------------------------------------------
echo "Gerando .pcppass para autenticação dos clientes PCP no serviço Pgpool-II..."
echo "*:9898:${PGPOOL_PCP_USER}:${PGPOOL_PCP_PASSWORD}" > "${HOME}/.pcppass"


# ------------------------------------------------------------------------------------
# Define permissões seguras para os arquivos de senha.
# Apenas o proprietário (usuário 'pgpool') poderá ler os arquivos.
# ------------------------------------------------------------------------------------
# --- Permissões ---
chmod 600 "${HOME}/.pgpass" "${HOME}/.pcppass"

echo "✅ Arquivos de senha criados com segurança em ${HOME}."