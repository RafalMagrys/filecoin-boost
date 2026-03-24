#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
require_devnet
require_env PRIVATE_KEY_TEST
require_env FILECOIN_PAY

RAIL_ID="${1:-}"

if [ -z "$RAIL_ID" ]; then
    echo "Usage: $0 <RAIL_ID>"
    echo "Example: $0 42"
    exit 1
fi

DEPLOYER=$(cast wallet address "$PRIVATE_KEY_TEST")
echo "Method:       settleRail(uint256)"
echo "Caller:       $DEPLOYER"
echo "Rail ID:      $RAIL_ID"
echo ""

cast send $FILECOIN_PAY \
  "settleRail(uint256)" \
  $RAIL_ID \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY_TEST

echo "Done."
