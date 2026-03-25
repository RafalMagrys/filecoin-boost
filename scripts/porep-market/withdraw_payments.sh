#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
require_devnet
require_env FILECOIN_PAY
require_env PRIVATE_KEY_TEST

TOKEN="${1:-}"
AMOUNT="${2:-}"

if [ -z "$TOKEN" ] || [ -z "$AMOUNT" ]; then
    echo "Usage: $0 <RAIL_ID>"
    echo "Example: $0 42"
    exit 1
fi

echo "Method:   withdraw(address,uint256)"
echo "Token:  $TOKEN"
echo "Amount:  $AMOUNT"
echo ""

cast send \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY_TEST \
  --gas-limit 9000000000 \
  $FILECOIN_PAY \
  "withdraw(address,uint256)" \
  "$TOKEN" "$AMOUNT"

wait_for_tx

echo "Done."