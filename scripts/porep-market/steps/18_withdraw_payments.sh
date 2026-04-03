#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

require_devnet

state_load
state_require DEPLOYER
require_env PRIVATE_KEY_TEST FILECOIN_PAY USDC_TOKEN

AMOUNT="${1:-$(state_get PAID_AMOUNT)}"
[ -n "$AMOUNT" ] || { echo "ERROR: AMOUNT required (arg or state PAID_AMOUNT)"; exit 1; }

echo "Method:   withdraw(address,uint256)"
echo "Token:    $USDC_TOKEN"
echo "Amount:   $AMOUNT"
echo "Receiver: $DEPLOYER"

echo
echo "Reading balance BEFORE..."

BALANCE_BEFORE=$(cast call \
  --rpc-url $RPC_URL \
  $USDC_TOKEN \
  "balanceOf(address)(uint256)" \
  $DEPLOYER | awk '{print $1}')

echo "Balance before: $BALANCE_BEFORE"

echo
echo "Sending withdraw transaction..."

TX_HASH=$(cast send \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY_SP \
  --gas-limit 9000000000 \
  $FILECOIN_PAY \
  "withdraw(address,uint256)" \
  "$USDC_TOKEN" "$AMOUNT" \
  --json | jq -r '.transactionHash')

wait_for_tx "$TX_HASH"

echo
echo "Reading balance AFTER..."

BALANCE_AFTER=$(cast call \
  --rpc-url $RPC_URL \
  $USDC_TOKEN \
  "balanceOf(address)(uint256)" \
  $DEPLOYER | awk '{print $1}')

echo "Balance after:  $BALANCE_AFTER"

DIFF=$((BALANCE_AFTER - BALANCE_BEFORE))

echo
echo "Received: $DIFF"