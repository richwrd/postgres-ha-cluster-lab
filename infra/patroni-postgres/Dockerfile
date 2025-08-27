FROM postgres:17

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-venv \
    python3-pip \
    python3-etcd \
    build-essential \
    curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/patroni \
    && /opt/patroni/bin/pip install --upgrade pip \
    && /opt/patroni/bin/pip install "psycopg[binary]" \
    && /opt/patroni/bin/pip install "patroni[etcd]==4.0.6"

ENV PATH="/opt/patroni/bin:$PATH"

COPY config/patroni.yaml /etc/patroni.yaml

EXPOSE 5432 8008

USER postgres

CMD ["patroni", "/etc/patroni.yaml"]