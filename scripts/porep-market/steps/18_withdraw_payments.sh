#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

require_devnet
require_env PRIVATE_KEY_TEST FILECOIN_PAY USDC_TOKEN DEPLOYER

AMOUNT="${1:-}"

if [ -z "$AMOUNT" ]; then
    echo "Usage: $0 <AMOUNT>"
    echo "Example: $0 42000000   # 42 USDC (6 decimals)"
    exit 1
fi

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

cast send \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY_TEST \
  --gas-limit 9000000000 \
  $FILECOIN_PAY \
  "withdraw(address,uint256)" \
  "$USDC_TOKEN" "$AMOUNT"

wait_for_tx

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