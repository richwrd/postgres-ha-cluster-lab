#!/bin/bash
# /etc/pgpool2/failover.sh
# Script básico para failover

FAILED_NODE_ID=$1
FAILED_NODE_HOST=$2
FAILED_NODE_PORT=$3
NEW_PRIMARY_ID=$4
NEW_PRIMARY_HOST=$5
OLD_PRIMARY_ID=$6
OLD_PRIMARY_PORT=$7

LOG_FILE="/var/log/pgpool/failover.log"

echo "$(date '+%Y-%m-%d %H:%M:%S') - Failover iniciado:
- Nó falho: $FAILED_NODE_ID ($FAILED_NODE_HOST:$FAILED_NODE_PORT)
- Novo primário: $NEW_PRIMARY_ID ($NEW_PRIMARY_HOST)
- Primário antigo: $OLD_PRIMARY_ID" >> $LOG_FILE

exit 0