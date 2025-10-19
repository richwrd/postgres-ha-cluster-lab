#!/bin/sh
set -e

# Caminho do pool_passwd deve bater com o pgpool.conf (pool_passwd = '/opt/pgpool/pool_passwd')
POOL_PASSWD_PATH="${POOL_PASSWD_PATH:-/opt/pgpool/pool_passwd}"

# Verifica HOME para gerar .pgpass e .pcppass corretamente
if [ -z "$HOME" ]; then
  echo "ERRO: A variável de ambiente HOME não está definida." >&2
  exit 1
fi

# Valida variáveis mínimas
: "${PGPOOL_HEALTHCHECK_USER:?PGPOOL_HEALTHCHECK_USER não definido}"
: "${PGPOOL_HEALTHCHECK_PASSWORD:?PGPOOL_HEALTHCHECK_PASSWORD não definido}"
: "${PGPOOL_SR_CHECK_USER:?PGPOOL_SR_CHECK_USER não definido}"
: "${PGPOOL_SR_CHECK_PASSWORD:?PGPOOL_SR_CHECK_PASSWORD não definido}"
: "${PGPOOL_PCP_USER:?PGPOOL_PCP_USER não definido}"
: "${PGPOOL_PCP_PASSWORD:?PGPOOL_PCP_PASSWORD não definido}"

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
# pool_passwd: Senhas que o Pgpool usa para autenticar nos backends PostgreSQL
# Formato: usuario:md5hash
# O hash MD5 do PostgreSQL é calculado como: md5(senha + usuario)
#
# IMPORTANTE: Com enable_pool_hba = on, este arquivo só precisa conter as credenciais
# dos usuários INTERNOS do PgPool (healthchecker, replicator). As senhas dos usuários
# de aplicação são repassadas diretamente ao PostgreSQL via pass-through authentication.
# ------------------------------------------------------------------------------------
echo "Gerando pool_passwd..."
mkdir -p "$(dirname "${POOL_PASSWD_PATH}")"

# Gera hashes MD5 no formato PostgreSQL: md5(password + username)
{
  pg_md5 -m -u "${PGPOOL_HEALTHCHECK_USER}" "${PGPOOL_HEALTHCHECK_PASSWORD}"
  pg_md5 -m -u "${PGPOOL_SR_CHECK_USER}" "${PGPOOL_SR_CHECK_PASSWORD}"
  pg_md5 -m -u "${TEST_DB_USERNAME}" "${TEST_DB_PASSWORD}"
} > "${POOL_PASSWD_PATH}"

# ------------------------------------------------------------------------------------
# pcp.conf: Usado pelo SERVIDOR Pgpool-II para validar credenciais dos clientes PCP que se conectam à porta 9898
# Formato: usuario:md5hash_simples
# ------------------------------------------------------------------------------------
echo "Gerando pcp.conf..."
PCP_CONF_PATH="/opt/pgpool/etc/pcp.conf"
echo "${PGPOOL_PCP_USER}:$(pg_md5 "${PGPOOL_PCP_PASSWORD}")" > "${PCP_CONF_PATH}"


# ------------------------------------------------------------------------------------
# Define permissões seguras para os arquivos de senha.
# Apenas o proprietário (usuário 'pgpool') poderá ler os arquivos.
# ------------------------------------------------------------------------------------
# --- Permissões ---
chmod 600 "${HOME}/.pgpass" "${HOME}/.pcppass" "${POOL_PASSWD_PATH}" "${PCP_CONF_PATH}" || true


echo "✅ Arquivos de senha criados com segurança:"
echo " - ${HOME}/.pgpass"
echo " - ${HOME}/.pcppass"
echo " - ${POOL_PASSWD_PATH}"
echo " - ${PCP_CONF_PATH}"