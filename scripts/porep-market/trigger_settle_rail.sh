#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
require_devnet
require_env PRIVATE_KEY_TEST FILECOIN_PAY 

RAIL_ID="${1:-}"

if [ -z "$RAIL_ID" ]; then
    echo "Usage: $0 <RAIL_ID>"
    echo "Example: $0 42"
    exit 1
fi

UNTIL_EPOCH=$(cast bn --rpc-url $RPC_URL)

echo "Method:       settleRail(uint256,uint256)"
echo "Rail ID:      $RAIL_ID"
echo "Until epoch:  $UNTIL_EPOCH"
echo ""

SETTLE_RAIL_TX_HASH=$(cast send \
  $FILECOIN_PAY \
  "settleRail(uint256,uint256)" \
  $RAIL_ID \
  $UNTIL_EPOCH \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY_TEST \
  --gas-limit 9000000000 \
  --json | jq -r '.transactionHash')

update_env "SETTLE_RAIL_TX_HASH" "$SETTLE_RAIL_TX_HASH"

wait_for_tx

echo "Done."
