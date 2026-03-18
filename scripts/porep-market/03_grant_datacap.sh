#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
require_devnet
require_env CLIENT_CONTRACT

echo "=== Grant DataCap to Client contract ==="

ALLOCATOR_WALLET=$(docker exec lotus lotus wallet new | tr -d '\r\n')
echo "Allocator wallet: $ALLOCATOR_WALLET"

docker exec lotus lotus send "$ALLOCATOR_WALLET" 10000
wait_for_tx

CLIENT_FIL_ADDR=$(docker exec lotus lotus evm stat "$CLIENT_CONTRACT" | awk '/Filecoin address:/{print $3}' | tr -d '\r\n')
echo "Client FIL addr: $CLIENT_FIL_ADDR"
update_env "CLIENT_FIL_ADDR" "$CLIENT_FIL_ADDR"

# Add allocator as verifier (t0100 = verifreg root on devnet)
docker exec lotus lotus-shed verifreg add-verifier t0100 "$ALLOCATOR_WALLET" 99999999999

# Approve the multisig tx
LATEST_TX_ID=$(docker exec lotus lotus msig inspect f080 | \
    awk '/^Transactions:/{flag=1; next} flag && /^[0-9]+/{print $1}' | sort -nr | head -n1)

if [ -n "$LATEST_TX_ID" ]; then
    echo "Approving msig tx $LATEST_TX_ID"
    docker exec lotus lotus msig approve --from t0101 f080 "$LATEST_TX_ID"
fi
wait_for_tx

docker exec lotus lotus filplus list-notaries

docker exec lotus lotus filplus grant-datacap --from "$ALLOCATOR_WALLET" "$CLIENT_FIL_ADDR" 99999999999
wait_for_tx

echo "Verifying..."
docker exec lotus lotus filplus check-client-datacap "$CLIENT_FIL_ADDR"

update_env "ALLOCATOR_WALLET" "$ALLOCATOR_WALLET"
echo "Done."
