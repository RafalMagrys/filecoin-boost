#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
require_devnet
require_env PRIVATE_KEY_TEST
require_env CLIENT_CONTRACT

DEPLOYER=$(cast wallet address "$PRIVATE_KEY_TEST")
echo "Deployer: $DEPLOYER"

# Fund deployer (idempotent)
docker exec lotus lotus send "$DEPLOYER" 10000 2>/dev/null || true
wait_for_tx

# Helper: propose add-verifier and approve the resulting msig TX.
# Captures TX count before proposal to reliably find the new TX.
propose_and_approve_verifier() {
    local addr="$1" amount="$2"

    # Snapshot current highest TX ID (may be empty on first call)
    local before_tx_id
    before_tx_id=$(docker exec lotus lotus msig inspect f080 | \
        awk '/^Transactions:/{flag=1; next} flag && /^[0-9]+/{print $1}' | sort -nr | head -n1)

    docker exec lotus lotus-shed verifreg add-verifier t0100 "$addr" "$amount"

    local new_tx_id
    new_tx_id=$(docker exec lotus lotus msig inspect f080 | \
        awk '/^Transactions:/{flag=1; next} flag && /^[0-9]+/{print $1}' | sort -nr | head -n1)

    if [ -n "$new_tx_id" ] && [ "$new_tx_id" != "${before_tx_id:-}" ]; then
        echo "  Approving msig tx $new_tx_id"
        docker exec lotus lotus msig approve --from t0101 f080 "$new_tx_id"
    else
        echo "  WARN: no new msig TX detected"
    fi
    wait_for_tx
}

# ============================================================
# Phase 1: Deploy MetaAllocator (per README: forge create flow)
# ============================================================
echo "=== Phase 1: Deploy MetaAllocator ==="

cd "$METAALLOC_DIR"

echo "Deploying Allocator implementation..."
ALLOC_IMPL=$(forge create src/Allocator.sol:Allocator \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY_TEST" \
    --broadcast --json 2>/dev/null | jq -r '.deployedTo')
[ -n "$ALLOC_IMPL" ] && [ "$ALLOC_IMPL" != "null" ] || { echo "ERROR: Allocator deploy failed"; exit 1; }
echo "  Allocator impl: $ALLOC_IMPL"
wait_for_tx

echo "Deploying Factory..."
FACTORY=$(forge create src/Factory.sol:Factory \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY_TEST" \
    --broadcast --json \
    --constructor-args "$DEPLOYER" "$ALLOC_IMPL" \
    2>/dev/null | jq -r '.deployedTo')
[ -n "$FACTORY" ] && [ "$FACTORY" != "null" ] || { echo "ERROR: Factory deploy failed"; exit 1; }
echo "  Factory: $FACTORY"
wait_for_tx

echo "Creating Allocator proxy via Factory..."
cast send --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY_TEST" \
    "$FACTORY" 'deploy(address)' "$DEPLOYER"
wait_for_tx

META_ALLOCATOR=$(cast call --rpc-url "$RPC_URL" "$FACTORY" 'contracts(uint256)(address)' 0)
echo "  MetaAllocator proxy: $META_ALLOCATOR"

update_env "META_ALLOCATOR" "$META_ALLOCATOR"
update_env "ALLOCATOR_FACTORY" "$FACTORY"

# ============================================================
# Phase 2: Make MetaAllocator a verifier (notary)
# ============================================================
echo "=== Phase 2: Register MetaAllocator as verifier ==="

META_FIL_ADDR=$(docker exec lotus lotus evm stat "$META_ALLOCATOR" \
    | awk '/Filecoin address:/{print $3}' | tr -d '\r\n')
echo "  MetaAllocator FIL addr: $META_FIL_ADDR"

propose_and_approve_verifier "$META_FIL_ADDR" 999999999999999999

echo "  Verifiers:"
docker exec lotus lotus filplus list-notaries

# ============================================================
# Phase 3: Grant allowance on MetaAllocator to deployer
# ============================================================
echo "=== Phase 3: Grant allowance to deployer on MetaAllocator ==="

cast send --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY_TEST" \
    "$META_ALLOCATOR" 'addAllowance(address,uint256)' \
    "$DEPLOYER" 999999999999999999
wait_for_tx

echo "  Deployer allowance: $(cast call --rpc-url "$RPC_URL" \
    "$META_ALLOCATOR" 'allowance(address)(uint256)' "$DEPLOYER")"

# ============================================================
# Phase 4: Grant datacap to Client.sol via MetaAllocator
# ============================================================
echo "=== Phase 4: Grant datacap to Client via addVerifiedClient ==="

# Build f4 address bytes: 0x04 (protocol 4) + 0x0a (EAM id=10) + 20-byte eth addr
CLIENT_LOWER=$(echo "$CLIENT_CONTRACT" | tr '[:upper:]' '[:lower:]')
CLIENT_FIL_BYTES="0x040a${CLIENT_LOWER#0x}"
echo "  Client f4 bytes: $CLIENT_FIL_BYTES"

cast send --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY_TEST" \
    "$META_ALLOCATOR" 'addVerifiedClient(bytes,uint256)' \
    "$CLIENT_FIL_BYTES" 99999999999999
wait_for_tx

CLIENT_FIL_ADDR=$(docker exec lotus lotus evm stat "$CLIENT_CONTRACT" \
    | awk '/Filecoin address:/{print $3}' | tr -d '\r\n')
echo "  Client FIL addr: $CLIENT_FIL_ADDR"
update_env "CLIENT_FIL_ADDR" "$CLIENT_FIL_ADDR"

echo "  Verifying datacap via MetaAllocator..."
docker exec lotus lotus filplus check-client-datacap "$CLIENT_FIL_ADDR" || true

# ============================================================
# Phase 5: TEMPORARY — direct datacap grant to Client.sol
# TODO: Remove this phase once full MetaAllocator flow is validated
# ============================================================
echo "=== Phase 5: TEMPORARY direct datacap grant ==="

VERIFIER_WALLET=$(docker exec lotus lotus wallet new | tr -d '\r\n')
echo "  Verifier wallet: $VERIFIER_WALLET"
docker exec lotus lotus send "$VERIFIER_WALLET" 10000
wait_for_tx

propose_and_approve_verifier "$VERIFIER_WALLET" 999999999999999999

docker exec lotus lotus filplus grant-datacap \
    --from "$VERIFIER_WALLET" "$CLIENT_FIL_ADDR" 99999999999
wait_for_tx

echo "  Final datacap check:"
docker exec lotus lotus filplus check-client-datacap "$CLIENT_FIL_ADDR"

update_env "VERIFIER_WALLET" "$VERIFIER_WALLET"
echo "Done."
