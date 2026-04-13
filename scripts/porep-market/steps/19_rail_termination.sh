#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
require_devnet
require_env PRIVATE_KEY_TEST

state_load
state_require VALIDATOR RAIL_ID

echo "Method:   terminateRail(uint256)"
echo "Caller:   $VALIDATOR"
echo "RailID:   $RAIL_ID"
echo ""

TX_HASH=$(cast send \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY_TEST" \
    --gas-limit 9000000000 \
    "$VALIDATOR" \
    "terminateRail(uint256)" \
    "$RAIL_ID" \
    --json 2>/dev/null | jq -r '.transactionHash')

wait_for_tx "$TX_HASH"

RECEIPT=$(cast receipt --rpc-url "$RPC_URL" "$TX_HASH" --json)
TERMINATION_BLOCK=$(echo "$RECEIPT" | jq -r '.blockNumber' | cast --to-dec)
TERMINATION_TX_HASH="$TX_HASH"

EVENT_SIG=$(cast keccak "RailTerminated(uint256,address,uint256)")
TERMINATION_END_EPOCH=$(echo "$RECEIPT" | jq -r --arg sig "$EVENT_SIG" '
    .logs[] | select(.topics[0] == $sig) | .data
' | head -1 | cast --to-dec)

state_set TERMINATION_BLOCK "$TERMINATION_BLOCK"
state_set TERMINATION_TX_HASH "$TERMINATION_TX_HASH"
state_set TERMINATION_END_EPOCH "$TERMINATION_END_EPOCH"

echo ""
echo "=== Termination completed ==="
echo "  Termination block:     $TERMINATION_BLOCK"
echo "  Termination end epoch: $TERMINATION_END_EPOCH"
echo "  Termination tx hash:   $TERMINATION_TX_HASH"
