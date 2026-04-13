#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"
POREP_DIR="$SCRIPT_DIR/../porep-market"
METAALLOC_DIR="$SCRIPT_DIR/../contract-metaallocator"

if [ -f "$ENV_FILE" ]; then
    set -a; source "$ENV_FILE"; set +a
fi

RPC_URL="${RPC_URL:-http://127.0.0.1:1234/rpc/v1}"
MINER_ACTOR_ID="${MINER_ACTOR_ID:-1000}"

require_env() {
    for var in "$@"; do
        if [ -z "${!var:-}" ]; then
            echo "ERROR: $var not set. Check $ENV_FILE" && exit 1
        fi
    done
}

require_devnet() {
    docker exec lotus lotus chain head &>/dev/null || { echo "ERROR: Devnet not running (make devnet/up)"; exit 1; }
}

require_porep() {
    [ -d "$POREP_DIR" ] || { echo "ERROR: porep-market not cloned. Run 00_setup.sh"; exit 1; }
}

update_env() {
    local key="$1" val="$2"
    [ -f "$ENV_FILE" ] || cp "$SCRIPT_DIR/../env.example" "$ENV_FILE"
    if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${val}|" "$ENV_FILE"
    else
        echo "${key}=${val}" >> "$ENV_FILE"
    fi
}

wait_for_tx() {
    local tx_hash="${1:-}"
    if [ -z "$tx_hash" ]; then
        sleep 15
        return
    fi
    local attempts=0
    while [ $attempts -lt 60 ]; do
        local status
        status=$(cast receipt --rpc-url "$RPC_URL" "$tx_hash" --json 2>/dev/null | jq -r '.status // empty' 2>/dev/null) || true
        if [ "$status" = "0x1" ]; then
            return 0
        elif [ "$status" = "0x0" ]; then
            echo "ERROR: tx $tx_hash reverted"
            return 1
        fi
        attempts=$((attempts + 1))
        [ $((attempts % 6)) -ne 0 ] || echo "  [wait_for_tx] still waiting for ${tx_hash:0:12}... (${attempts} checks / $((attempts * 5))s)" >&2
        sleep 5
    done
    echo "ERROR: tx $tx_hash not mined after 5 minutes"
    return 1
}

wait_for_block() {
    local target_block="${1:-}"
    local current_block
    current_block=$(cast block-number --rpc-url "$RPC_URL" 2>/dev/null)
    while [ "$current_block" -lt "$target_block" ]; do
        echo "  [wait_for_block] still waiting for ${target_block} (${current_block} / ${target_block})" >&2
        sleep 5
        current_block=$(cast block-number --rpc-url "$RPC_URL" 2>/dev/null)
    done
}

# --- State file management ---
STATE_FILE="${STATE_FILE:-$SCRIPT_DIR/../.state}"

state_set() {
    local key="$1" val="$2"
    if [ ! -f "$STATE_FILE" ]; then
        [ -f "$SCRIPT_DIR/../state.example" ] && cp "$SCRIPT_DIR/../state.example" "$STATE_FILE" || touch "$STATE_FILE"
    fi
    if grep -q "^${key}=" "$STATE_FILE" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${val}|" "$STATE_FILE"
    else
        echo "${key}=${val}" >> "$STATE_FILE"
    fi
    export "$key=$val"
}

state_get() {
    local key="$1"
    if [ -n "${!key:-}" ]; then
        echo "${!key}"
        return
    fi
    if [ -f "$STATE_FILE" ]; then
        grep "^${key}=" "$STATE_FILE" 2>/dev/null | cut -d= -f2-
    fi
}

state_require() {
    for var in "$@"; do
        local val
        val=$(state_get "$var")
        if [ -z "$val" ]; then
            echo "ERROR: $var not in state. Run prerequisite step first." && exit 1
        fi
        export "$var=$val"
    done
}

state_load() {
    if [ -f "$STATE_FILE" ]; then
        set -a; source "$STATE_FILE"; set +a
    fi
}

state_init() {
    STATE_FILE="${1:-$STATE_FILE}"
    export STATE_FILE
    state_load
}

# --- Cast helpers ---
csend() {
    local key="${SENDER_KEY:-$PRIVATE_KEY_TEST}"
    local tx_hash
    tx_hash=$(cast send --gas-limit 9000000000 --rpc-url "$RPC_URL" --private-key "$key" "$@" --json 2>/dev/null | jq -r '.transactionHash // empty')
    if [ -z "$tx_hash" ]; then
        echo "ERROR: csend failed to submit tx"
        return 1
    fi
    wait_for_tx "$tx_hash"
}

ccall() {
    cast call --rpc-url "$RPC_URL" "$@"
}

get_deal_field() {
    local deal_id="$1" field="$2"
    ccall "$POREP_MARKET" "getDealProposal(uint256)((uint256,address,uint64,(uint16,uint16,uint16,uint8),(uint256,uint256,uint32),address,uint8,uint256,string))" \
        "$deal_id" 2>/dev/null | sed 's/[()]//g; s/ \[[^]]*\]//g' | tr ',' '\n' | sed -n "${field}p" | tr -d ' '
}
