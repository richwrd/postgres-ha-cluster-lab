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
# pool_passwd para o Pgpool autenticar no PostgreSQL quando backend exigir senha
# Formato TEXT é compatível com SCRAM (e também funciona com md5 no backend)
# Linha no formato: usuario:TEXTsenha
# ------------------------------------------------------------------------------------
echo "Gerando pool_passwd (formato TEXT) para autenticação do Pgpool-II com os backends..."
mkdir -p "$(dirname "${POOL_PASSWD_PATH}")"

# Cria/atualiza entradas necessárias
# Atenção: não use underscore após TEXT; o prefixo é 'TEXT' colado na senha
{
  echo "${PGPOOL_HEALTHCHECK_USER}:TEXT${PGPOOL_HEALTHCHECK_PASSWORD}"
  echo "${PGPOOL_SR_CHECK_USER}:TEXT${PGPOOL_SR_CHECK_PASSWORD}"
} > "${POOL_PASSWD_PATH}"


# ------------------------------------------------------------------------------------
# Define permissões seguras para os arquivos de senha.
# Apenas o proprietário (usuário 'pgpool') poderá ler os arquivos.
# ------------------------------------------------------------------------------------
# --- Permissões ---
chmod 600 "${HOME}/.pgpass" "${HOME}/.pcppass" "${POOL_PASSWD_PATH}" || true


echo "✅ Arquivos de senha criados com segurança:"
echo " - ${HOME}/.pgpass"
echo " - ${HOME}/.pcppass"
echo " - ${POOL_PASSWD_PATH}"