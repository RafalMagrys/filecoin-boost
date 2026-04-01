#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
require_devnet
require_porep
require_env PRIVATE_KEY_TEST

DEPLOYER=$(cast wallet address "$PRIVATE_KEY_TEST")
echo "Deployer: $DEPLOYER"

docker exec lotus lotus send "$DEPLOYER" 10000 2>/dev/null || true
wait_for_tx

# Deploy FilecoinPay if available
FILPAY_DIR="$SCRIPT_DIR/filecoin-pay"
if [ -d "$FILPAY_DIR" ]; then
    echo "Deploying FilecoinPay..."
    cd "$FILPAY_DIR"
    FILPAY_ADDR=$(forge create src/FilecoinPayV1.sol:FilecoinPayV1 \
        --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY_TEST" \
        --broadcast --json 2>/dev/null | jq -r '.deployedTo')
    echo "FilecoinPay: $FILPAY_ADDR"
    update_env "FILECOIN_PAY" "$FILPAY_ADDR"
    wait_for_tx
else
    echo "WARN: filecoin-pay not cloned, using deployer as placeholder"
    FILPAY_ADDR="$DEPLOYER"
fi

# Deploy MetaAllocator before main contracts (Deploy.s.sol requires META_ALLOCATOR)
if [ -z "${META_ALLOCATOR:-}" ]; then
    echo "Deploying MetaAllocator..."
    cd "$METAALLOC_DIR"

    ALLOC_IMPL=$(forge create src/Allocator.sol:Allocator \
        --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY_TEST" \
        --broadcast --json 2>/dev/null | jq -r '.deployedTo')
    [ -n "$ALLOC_IMPL" ] && [ "$ALLOC_IMPL" != "null" ] || { echo "ERROR: Allocator deploy failed"; exit 1; }
    echo "  Allocator impl: $ALLOC_IMPL"
    wait_for_tx

    FACTORY=$(forge create src/Factory.sol:Factory \
        --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY_TEST" \
        --broadcast --json \
        --constructor-args "$DEPLOYER" "$ALLOC_IMPL" \
        2>/dev/null | jq -r '.deployedTo')
    [ -n "$FACTORY" ] && [ "$FACTORY" != "null" ] || { echo "ERROR: Factory deploy failed"; exit 1; }
    echo "  Factory: $FACTORY"
    wait_for_tx

    cast send --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY_TEST" \
        "$FACTORY" 'deploy(address)' "$DEPLOYER"
    wait_for_tx

    META_ALLOCATOR=$(cast call --rpc-url "$RPC_URL" "$FACTORY" 'contracts(uint256)(address)' 0)
    echo "  MetaAllocator proxy: $META_ALLOCATOR"

    update_env "META_ALLOCATOR" "$META_ALLOCATOR"
    update_env "ALLOCATOR_FACTORY" "$FACTORY"
else
    echo "MetaAllocator already deployed: $META_ALLOCATOR"
fi

cd "$POREP_DIR"

export PRIVATE_KEY="$PRIVATE_KEY_TEST"
export TERMINATION_ORACLE="$DEPLOYER"
export FILECOIN_PAY="$FILPAY_ADDR"
export ORACLE="$DEPLOYER"
export POREP_SERVICE="$DEPLOYER"
export OPERATOR_ADDR="$DEPLOYER"
export ALLOCATOR="$DEPLOYER"
export META_ALLOCATOR

forge clean && forge build

DEPLOY_OUTPUT=$(forge script script/Deploy.s.sol \
    --gas-estimate-multiplier 100000 \
    --disable-block-gas-limit \
    --broadcast \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY_TEST" \
    -vvvv 2>&1) || true

echo "$DEPLOY_OUTPUT" > "$SCRIPT_DIR/deploy_output.log"

echo "$DEPLOY_OUTPUT" | grep -q "ONCHAIN EXECUTION COMPLETE & SUCCESSFUL" || { echo "ERROR: deploy failed, check deploy_output.log"; exit 1; }

DEPLOY_JSON="$POREP_DIR/deployments/devnet/latest.json"
[ -f "$DEPLOY_JSON" ] || { echo "ERROR: $DEPLOY_JSON not found"; exit 1; }

extract_addr() {
    local val
    val=$(jq -r ".$1" "$DEPLOY_JSON")
    echo "$val" | grep -q "^0x" && echo "$val" || jq -r ".$1.proxy" "$DEPLOY_JSON"
}

for name in PoRepMarket Client SPRegistry ValidatorFactory SLIOracle SLIScorer; do
    addr=$(extract_addr "$name")
    case "$name" in
        PoRepMarket)       update_env "POREP_MARKET" "$addr" ;;
        Client)            update_env "CLIENT_CONTRACT" "$addr" ;;
        SPRegistry)        update_env "SP_REGISTRY" "$addr" ;;
        ValidatorFactory)  update_env "VALIDATOR_FACTORY" "$addr" ;;
        SLIOracle)         update_env "SLI_ORACLE" "$addr" ;;
        SLIScorer)         update_env "SLI_SCORER" "$addr" ;;
    esac
    printf "  %-20s %s\n" "$name" "$addr"
done

echo "Addresses saved to .env"
