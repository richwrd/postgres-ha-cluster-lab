#!/bin/sh
set -e

STARTUP_DIR="/opt/pgpool/bin/scripts/startup"

echo "🚀 Iniciando processo de inicialização do Pgpool-II..."
echo "══════════════════════════════════════════════════════"

# --- ETAPA 1: Aguardar o Patroni ---
echo "▶️ Etapa 1/3: Aguardando a API do Patroni..."
sh "${STARTUP_DIR}/01_wait_for_patroni.sh"
echo "══════════════════════════════════════════════════════"

# --- ETAPA 2: Gerar o pgpool.conf ---
echo "▶️ Etapa 2/3: Gerando configuração do Pgpool-II..."
sh "${STARTUP_DIR}/02_generate_pgpool_config.sh"
echo "══════════════════════════════════════════════════════"

# --- ETAPA 3: Gerar arquivos de senha ---
echo "▶️ Etapa 3/3: Gerando arquivos de senha..."
sh "${STARTUP_DIR}/03_generate_passwords.sh"
echo "══════════════════════════════════════════════════════"

# --- Gerenciamento do Processo ---
# Função de encerramento gracioso
shutdown() {
  echo "SIGTERM recebido, encerrando o Pgpool-II..."
  /opt/pgpool/bin/pgpool -m fast stop
  exit 0
}
trap shutdown TERM INT

echo "✅ Configuração concluída. Iniciando o processo principal do Pgpool-II..."
# Executa o comando passado para o container (o CMD do Dockerfile)
exec /opt/pgpool/bin/pgpool -n -f /opt/pgpool/etc/pgpool.conf