#!/bin/bash
set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

require_devnet
require_env PRIVATE_KEY_TEST
require_env POREP_MARKET

state_load

# --------------------------
# INPUT
# --------------------------
DEAL_ID="${1:-$(state_get DEAL_ID)}"
[ -n "$DEAL_ID" ] || { echo "ERROR: DEAL_ID required (arg or state)"; exit 1; }

DEPLOYER=$(cast wallet address "$PRIVATE_KEY_TEST")

echo "Accepting deal..."
echo "Market: $POREP_MARKET"
echo "Sender: $DEPLOYER"
echo "DealId: $DEAL_ID"

# --------------------------
# SEND TRANSACTION
# --------------------------
TX_HASH=$(cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY_TEST" \
  "$POREP_MARKET" \
  "acceptDeal(uint256)" \
  "$DEAL_ID" \
  --json | jq -r '.transactionHash')

wait_for_tx "$TX_HASH"

echo "Deal accepted successfully!"