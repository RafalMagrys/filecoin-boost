#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
require_devnet

DEFAULT_WALLET=$(docker exec lotus lotus wallet default | tr -d '\r\n')
echo "Default wallet: $DEFAULT_WALLET"

EXPORTED=$(docker exec lotus lotus wallet export "$DEFAULT_WALLET" | tr -d '\r\n')

# lotus exports base64 with type prefix byte — strip it, keep 32-byte key
PRIVATE_KEY=$(echo "$EXPORTED" | base64 -d | tail -c 32 | xxd -p -c 64)
echo "Private key: 0x${PRIVATE_KEY}"

update_env "PRIVATE_KEY_TEST" "0x${PRIVATE_KEY}"

DERIVED_ADDR=$(cast wallet address "0x${PRIVATE_KEY}" 2>/dev/null || echo "cast failed")
echo "ETH address: $DERIVED_ADDR"

docker exec lotus lotus send "$DEFAULT_WALLET" 10000 2>/dev/null || true

echo "Key saved to .env"
