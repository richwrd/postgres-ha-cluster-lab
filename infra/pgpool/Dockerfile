# ═══════════════════════════════════════════════════════════════════
# Dockerfile Genérico para Pgpool-II v4.6 (Otimizado para Docker Compose)
# by: Eduardo Richard
# ═══════════════════════════════════════════════════════════════════
# Objetivo: Criar uma imagem base leve e segura, contendo apenas o binário
# do Pgpool-II e suas dependências de runtime. Toda a configuração
# será injetada via volumes no Docker Compose.
# ═══════════════════════════════════════════════════════════════════

FROM debian:bullseye-slim

ARG PGPOOL_VERSION=4.6.3
ARG PG_MAJOR=17

ENV DEBIAN_FRONTEND=noninteractive

# --- Etapa 1: Instalação de Dependências de Build e Runtime ---
# Instala as ferramentas necessárias para compilar o Pgpool-II e
# utilitários que permanecerão na imagem final.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
        libssl-dev \
        curl \
        ca-certificates \
        gnupg \
        netcat-openbsd \
        jq && \
    rm -rf /var/lib/apt/lists/*

# --- Etapa 2: Download, Compilação e Instalação do Pgpool-II ---
# Baixa o código-fonte, compila e o instala no sistema.
# O uso de --chown=root:root no tar é uma boa prática de segurança.
RUN curl -sSL "https://www.pgpool.net/download.php?f=pgpool-II-${PGPOOL_VERSION}.tar.gz" -o pgpool-II.tar.gz && \
    tar -xzf pgpool-II.tar.gz && \
    rm pgpool-II.tar.gz && \
    cd pgpool-II-${PGPOOL_VERSION} && \
    ./configure --prefix=/opt/pgpool --without-readline && \
    make V=1 && \
    make && \
    make install && \
    cd .. && \
    rm -rf pgpool-II-${PGPOOL_VERSION}

# --- Etapa 3: Instalação do Cliente PostgreSQL ---
# Adiciona o repositório oficial do PostgreSQL e instala o cliente,
# que é uma dependência de runtime para os comandos pcp_*.
RUN curl -sS https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-key.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/postgresql-key.gpg] http://apt.postgresql.org/pub/repos/apt bullseye-pgdg main ${PG_MAJOR}" > /etc/apt/sources.list.d/pgdg.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends postgresql-client-${PG_MAJOR} && \
    rm -rf /var/lib/apt/lists/*

# --- Etapa 4: Limpeza e Criação de Usuário ---
# Remove as dependências que eram necessárias apenas para a compilação e
# cria o usuário não-root que executará o serviço.
RUN apt-get purge -y --auto-remove build-essential libpq-dev libssl-dev && \
    apt-get clean && \
    groupadd --system pgpool && \
    useradd --system --create-home --home-dir /home/pgpool --gid pgpool pgpool && \
    chown -R pgpool:pgpool /opt/pgpool

USER pgpool

EXPOSE 5432 9898

CMD ["/usr/local/bin/pgpool", "-n"]