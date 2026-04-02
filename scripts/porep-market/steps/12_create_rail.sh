#!/bin/bash
set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

require_devnet
require_env PRIVATE_KEY_TEST
require_env USDC_TOKEN

# --------------------------
# INPUT
# --------------------------
VALIDATOR=${1:?validator address required}

DEPLOYER=$(cast wallet address "$PRIVATE_KEY_TEST")

echo "Creating rail..."
echo "Validator: $VALIDATOR"
echo "Token:     $USDC_TOKEN"
echo "Sender:    $DEPLOYER"

# --------------------------
# SEND TRANSACTION
# --------------------------
cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY_TEST" \
  "$VALIDATOR" \
  "createRail(address)" \
  "$USDC_TOKEN"

wait_for_tx

echo "Rail created successfully!"