# ═══════════════════════════════════════════════════════════════════
# Dockerfile Genérico para Pgpool-II v4.6 (Otimizado para Docker Compose)
# by: Eduardo Richard
# ═══════════════════════════════════════════════════════════════════
# Objetivo: Criar uma imagem base leve e segura, contendo apenas o binário
# do Pgpool-II e suas dependências de runtime. Toda a configuração
# será injetada via volumes no Docker Compose.
# ═══════════════════════════════════════════════════════════════════

FROM debian:bullseye-slim

#Exemplo: 4.6.3 -> 4_6_3
ARG PGPOOL_VERSION=4_6_3
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
        jq \
        gosu \
        autoconf \
        automake \
        libtool \
        flex \
        bison && \
    rm -rf /var/lib/apt/lists/*

# --- Etapa 2: Instalação do Cliente PostgreSQL ---
# Adiciona o repositório oficial do PostgreSQL e instala o cliente,
# que é uma dependência de runtime para os comandos pcp_*.
RUN curl -sS https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-key.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/postgresql-key.gpg] http://apt.postgresql.org/pub/repos/apt bullseye-pgdg main ${PG_MAJOR}" > /etc/apt/sources.list.d/pgdg.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends postgresql-client-${PG_MAJOR} && \
    rm -rf /var/lib/apt/lists/*

# --- Etapa 3: Download, Compilação e Instalação do Pgpool-II ---
# Baixa o código-fonte do GitHub oficial.
# Usando GitHub releases para maior confiabilidade e disponibilidade.
RUN curl -fsSL -o pgpool-II.tar.gz \
        "https://github.com/pgpool/pgpool2/archive/refs/tags/V${PGPOOL_VERSION}.tar.gz" && \
    echo "Download concluído, extraindo arquivo..." && \
    tar -xzf pgpool-II.tar.gz && \
    rm pgpool-II.tar.gz && \
    echo "Listando diretórios extraídos..." && \
    ls -la && \
    echo "Entrando no diretório pgpool2-${PGPOOL_VERSION}..." && \
    cd pgpool2-${PGPOOL_VERSION} && \
    echo "Gerando script de configuração..." && \
    autoreconf -fiv && \
    echo "Configurando build..." && \
    ./configure --prefix=/opt/pgpool --without-readline && \
    echo "Compilando..." && \
    make V=1 && \
    make && \
    make install && \
    cd .. && \
    rm -rf pgpool2-${PGPOOL_VERSION}


# --- Etapa 4: Limpeza e Criação de Usuário ---
RUN apt-get install -y --no-install-recommends libpq5 libssl1.1 && \
    apt-get purge -y --auto-remove build-essential && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd --system pgpool && \
    useradd --system --create-home --home-dir /home/pgpool --gid pgpool pgpool && \
    chown -R pgpool:pgpool /opt/pgpool

# --- Etapa 5: Verificação de Ferramentas Instaladas ---
RUN echo "=== Verificando instalação do Pgpool-II ===" && \
    ls -la /opt/pgpool/bin/ && \
    /opt/pgpool/bin/pgpool --version

# --- Configuração de Ambiente ---
# Adiciona o diretório de binários do pgpool ao PATH
ENV PATH="/opt/pgpool/bin:${PATH}"

# Gosu é uma ferramenta que permite executar processos como outro usuário.
# Posteriormente, no entrypoint.sh, usaremos o gosu para iniciar o Pgpool-II como pgpool.
# Isso é uma prática recomendada de segurança, evitando a execução como root.
# USER pgpool

EXPOSE 5432 9898

CMD ["/opt/pgpool/bin/pgpool", "-n", "-f", "/opt/pgpool/etc/pgpool.conf"]