#!/bin/bash
set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

require_devnet
require_env PRIVATE_KEY_TEST
require_env VALIDATOR_FACTORY

# --------------------------
# INPUT
# --------------------------
DEAL_ID=${1:?dealId required}

DEPLOYER=$(cast wallet address "$PRIVATE_KEY_TEST")

echo "Creating validator..."
echo "Factory: $VALIDATOR_FACTORY"
echo "Sender:  $DEPLOYER"
echo "DealId:  $DEAL_ID"

# --------------------------
# SEND TRANSACTION
# --------------------------
cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY_TEST" \
  "$VALIDATOR_FACTORY" \
  "create(uint256)" \
  "$DEAL_ID"

wait_for_tx

echo "Validator created successfully!"