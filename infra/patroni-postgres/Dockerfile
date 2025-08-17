# =================================================================
# ESTÁGIO 1: Builder - Instala as ferramentas e dependências Python
# =================================================================
FROM python:3.11-slim-bullseye AS builder

RUN pip install --upgrade pip

# Instala o Patroni e o pgBackRest em um diretório alvo
# Isso nos dá controle exato da versão e evita conflitos com o 'apt'
RUN pip install --target=/install patroni[etcd]==3.3.0

# =================================================================
# ESTÁGIO 2: Final - A imagem final, limpa e otimizada
# =================================================================
FROM postgres:17

# Instala APENAS as dependências de RUNTIME (execução)
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-etcd \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copia as dependências Python instaladas no estágio 'builder'
COPY --from=builder /install /usr/local/lib/python3.11/site-packages

COPY config/patroni.yaml /etc/patroni.yaml
COPY config/pgbackrest.conf /etc/pgbackrest.conf

EXPOSE 5432 8008

USER postgres

CMD ["patroni", "/etc/patroni.yaml"]