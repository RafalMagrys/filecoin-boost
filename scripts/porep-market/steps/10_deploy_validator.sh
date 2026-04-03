#!/bin/bash
set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

require_devnet
require_env PRIVATE_KEY_TEST
require_env VALIDATOR_FACTORY

state_load

DEAL_ID="${1:-$(state_get DEAL_ID)}"
[ -n "$DEAL_ID" ] || { echo "ERROR: DEAL_ID required (arg or state)"; exit 1; }

DEPLOYER=$(cast wallet address "$PRIVATE_KEY_TEST")

echo "Creating validator..."
echo "Factory: $VALIDATOR_FACTORY"
echo "Sender:  $DEPLOYER"
echo "DealId:  $DEAL_ID"

# --------------------------
# SEND TX
# --------------------------

TX=$(cast send \
  --json \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY_TEST" \
  "$VALIDATOR_FACTORY" \
  "create(uint256)" \
  "$DEAL_ID")

wait_for_tx

echo "Transaction sent"

# --------------------------
# EXTRACT VALIDATOR ADDRESS
# --------------------------

VALIDATOR=$(echo "$TX" | jq -r '
.logs[]
| select(.topics[0] == "0x6c6ffd7df9a0cfaa14ee2cf752003968de6c340564276242aa48ca641b09bce4")
| .topics[1]
' | sed 's/^0x000000000000000000000000/0x/')

echo "Validator address: $VALIDATOR"
state_set VALIDATOR "$VALIDATOR"

# --------------------------
# SAVE TO validators.json
# --------------------------

FILE="$SCRIPT_DIR/validators.json"

if [ ! -f "$FILE" ]; then
  echo "{}" > "$FILE"
fi

TMP=$(mktemp)

jq --arg id "$DEAL_ID" --arg addr "$VALIDATOR" \
'. + {($id): $addr}' "$FILE" > "$TMP"

mv "$TMP" "$FILE"

echo "Saved to validators.json"
echo "Validator created successfully!"