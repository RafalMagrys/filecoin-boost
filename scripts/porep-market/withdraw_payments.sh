#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
require_devnet
require_env PRIVATE_KEY_TEST FILECOIN_PAY USDC_TOKEN SETTLE_RAIL_TX_HASH

AMOUNT="${1:-}"

if [ -z "$AMOUNT" ]; then
    echo "Usage: $0 <AMOUNT>"
    echo "Example: $0 42"
    exit 1
fi

echo "Method:   withdraw(address,uint256)"
echo "Token:    $USDC_TOKEN"
echo "Amount:   $AMOUNT"
echo ""

RAIL_ID_HEX="0x$(printf '%064x' $RAIL_ID)"
SETTLED=$(cast receipt $SETTLE_RAIL_TX_HASH --rpc-url $RPC_URL --json | jq \
  --arg railId "$RAIL_ID_HEX" \
  '[.logs[] | select(.topics[1] == $railId)] | length > 0')

$SETTLED && echo "Settlement OK for rail $RAIL_ID" || { echo "Settlement failed for rail $RAIL_ID"; exit 1; }

cast send \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY_TEST \
  --gas-limit 9000000000 \
  $FILECOIN_PAY \
  "withdraw(address,uint256)" \
  "$USDC_TOKEN" "$AMOUNT"

wait_for_tx

echo "Done."