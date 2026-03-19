#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
POREP_DIR="$SCRIPT_DIR/porep-market"
METAALLOC_DIR="$SCRIPT_DIR/contract-metaallocator"

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
    [ -f "$ENV_FILE" ] || cp "$SCRIPT_DIR/env.example" "$ENV_FILE"
    if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
        sed -i '' "s|^${key}=.*|${key}=${val}|" "$ENV_FILE"
    else
        echo "${key}=${val}" >> "$ENV_FILE"
    fi
}

wait_for_tx() { sleep 15; }
