#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
require_devnet
require_porep
require_env PRIVATE_KEY_TEST

DEPLOYER=$(cast wallet address "$PRIVATE_KEY_TEST")
echo "=== Deploy MockUSDC (6 decimals) ==="
echo "Deployer: $DEPLOYER"

cd "$POREP_DIR"

echo "Deploying MockUSDC..."
USDC_TOKEN=$(forge create "$SCRIPT_DIR/mocks/MockUSDC.sol:MockUSDC" \
    --constructor-args "Mock USDC" "USDC" \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY_TEST" \
    --broadcast --json 2>/dev/null | jq -r '.deployedTo')
[ -n "$USDC_TOKEN" ] && [ "$USDC_TOKEN" != "null" ] || { echo "ERROR: MockUSDC deploy failed"; exit 1; }
echo "  MockUSDC: $USDC_TOKEN"
update_env "USDC_TOKEN" "$USDC_TOKEN"
wait_for_tx

MINT_AMOUNT=1000000000000  # 1M USDC (1e12 with 6 decimals)
echo "Minting $MINT_AMOUNT to deployer..."
cast send --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY_TEST" \
    "$USDC_TOKEN" "mint(address,uint256)" "$DEPLOYER" "$MINT_AMOUNT"
wait_for_tx

BALANCE=$(cast call --rpc-url "$RPC_URL" "$USDC_TOKEN" "balanceOf(address)(uint256)" "$DEPLOYER")
echo "  Deployer USDC balance: $BALANCE"

echo "Done."
