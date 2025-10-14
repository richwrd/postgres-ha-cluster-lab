FROM postgres:17

ARG PATRONI_VERSION=4.0.6

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-venv \
    python3-pip \
    python3-etcd \
    build-essential \
    curl \
    vim \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/patroni \
    && /opt/patroni/bin/pip install --upgrade pip \
    && /opt/patroni/bin/pip install "psycopg[binary]" \
    && /opt/patroni/bin/pip install "patroni[etcd]==${PATRONI_VERSION}"

ENV PATH="/opt/patroni/bin:$PATH"

COPY config/patroni.yml /etc/patroni.yml
COPY config/scripts/post_bootstrap.sh /etc/patroni/scripts/post_bootstrap.sh

RUN chmod +x /etc/patroni/scripts/post_bootstrap.sh


EXPOSE 5432 8008

USER postgres

ENTRYPOINT ["patroni"]

CMD ["/etc/patroni.yml"]