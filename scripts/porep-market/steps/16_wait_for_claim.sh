#!/bin/bash
# Params:
#   MINER_ID             - numeric miner actor ID, derives t-address (default: 1000)
#   CLAIM_MAX_ATTEMPTS   - max polling attempts (default: 30)
#   CLAIM_POLL_SECONDS   - seconds between polls (default: 30)
# State in: ALLOC_ID
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
require_devnet

state_load
state_require ALLOC_ID

MINER_ID="${MINER_ID:-1000}"
MINER_ACTOR="t0${MINER_ID}"
MAX_ATTEMPTS="${CLAIM_MAX_ATTEMPTS:-30}"
POLL_INTERVAL="${CLAIM_POLL_SECONDS:-30}"

echo "=== Wait for Claim ==="
echo "  Allocation: $ALLOC_ID  Miner: $MINER_ACTOR"

docker exec lotus-miner lotus-miner sectors batching precommit --publish-now 2>/dev/null || true
docker exec lotus-miner lotus-miner sectors batching commit --publish-now 2>/dev/null || true

CLAIM_FOUND=0
for i in $(seq 1 "$MAX_ATTEMPTS"); do
    if docker exec lotus lotus filplus list-claims "$MINER_ACTOR" 2>/dev/null | \
       awk -v id="$ALLOC_ID" '$1 == id {found=1} END {exit !found}'; then
        CLAIM_FOUND=1
        echo "  Claim $ALLOC_ID confirmed on-chain"
        break
    fi
    docker exec lotus-miner lotus-miner sectors batching precommit --publish-now 2>/dev/null || true
    docker exec lotus-miner lotus-miner sectors batching commit --publish-now 2>/dev/null || true
    echo "  [$i/$MAX_ATTEMPTS] waiting... (${POLL_INTERVAL}s)"
    sleep "$POLL_INTERVAL"
done

[ "$CLAIM_FOUND" -eq 1 ] || { echo "ERROR: Claim $ALLOC_ID not found after $((MAX_ATTEMPTS * POLL_INTERVAL))s"; exit 1; }

echo "=== Claim confirmed ==="
