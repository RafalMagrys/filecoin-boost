#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
require_devnet
require_env PRIVATE_KEY_TEST

VALIDATOR="${1:-}"
RAIL_ID="${2:-}"

if [ -z "$VALIDATOR" ] || [ -z "$RAIL_ID" ]; then
    echo "Usage: $0 <VALIDATOR_ADDRESS> <RAIL_ID>"
    echo "Example: $0 0xAbCd...1234 42"
    exit 1
fi

DEPLOYER=$(cast wallet address "$PRIVATE_KEY_TEST")
echo "Method:       modifyRailPayment(uint256)"
echo "Caller:       $DEPLOYER"
echo "Validator:    $VALIDATOR"
echo "Rail ID:      $RAIL_ID"
echo ""

withRole "$VALIDATOR" POREP_SERVICE_ROLE "$DEPLOYER" \
    cast send \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY_TEST" \
    "$VALIDATOR" \
    "modifyRailPayment(uint256)" \
    "$RAIL_ID"

echo "Done."
