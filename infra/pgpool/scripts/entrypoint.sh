#!/bin/sh
set -e

STARTUP_DIR="/opt/pgpool/bin/scripts/startup"

echo "🚀 Iniciando processo de inicialização do Pgpool-II (como root)..."
echo "══════════════════════════════════════════════════════"

# --- Etapa 1: Preparar o ambiente de runtime (tarefas de root) ---
# Cria o diretório para o PID e sockets, que é um diretório temporário.
echo "Preparando diretórios de runtime em /var/run/pgpool..."
mkdir -p /var/run/pgpool
# Garante que o usuário 'pgpool' tenha permissão para escrever no diretório.
chown -R pgpool:pgpool /var/run/pgpool

mkdir -p /var/log/pgpool
chown -R pgpool:pgpool /var/log/pgpool


# --- ETAPA 1: Aguardar o Patroni ---
echo "▶️ Etapa 1/3: Aguardando a API do Patroni..."
gosu pgpool sh "${STARTUP_DIR}/01_wait_for_patroni.sh"
echo "══════════════════════════════════════════════════════"

# --- ETAPA 2: Gerar o pgpool.conf ---
echo "▶️ Etapa 2/3: Gerando configuração do Pgpool-II..."
gosu pgpool sh "${STARTUP_DIR}/02_generate_pgpool_config.sh"
echo "══════════════════════════════════════════════════════"

# --- ETAPA 3: Gerar arquivos de senha ---
echo "▶️ Etapa 3/3: Gerando arquivos de senha..."
gosu pgpool sh "${STARTUP_DIR}/03_generate_passwords.sh"

echo "══════════════════════════════════════════════════════"

# --- Gerenciamento do Processo ---
# Função de encerramento gracioso
shutdown() {
  echo "SIGTERM recebido, encerrando o Pgpool-II..."
  gosu pgpool /opt/pgpool/bin/pgpool -m fast stop
  exit 0
}
trap shutdown TERM INT

echo "✅ Configuração concluída. Iniciando o processo principal do Pgpool-II..."

exec gosu pgpool "$@"