#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
require_devnet

echo "=== Ensure Boost ==="

if ! docker exec boost curl -s http://localhost:8044 > /dev/null 2>&1; then
    docker exec -d boost bash -c \
        'boostd-data -vv run yugabyte --hosts yugabytedb --connect-string="postgresql://yugabyte:yugabyte@yugabytedb:5433?sslmode=disable" --addr 0.0.0.0:8044 &>/var/lib/boost/boostd-data.log' 2>/dev/null || true
    sleep 10
fi

if ! docker exec boost ls /var/lib/boost/api 2>/dev/null; then
    FULLNODE_API=$(docker exec lotus lotus auth api-info --perm=admin 2>/dev/null | cut -d= -f2-)
    docker exec -d boost bash -c \
        "export FULLNODE_API_INFO='$FULLNODE_API' && exec boostd -vv run --nosync=true --deprecated=true >> /var/lib/boost/boostd.log 2>&1" 2>/dev/null || true
    sleep 25
fi

echo "  Boost ready"
echo "=== Boost OK ==="
