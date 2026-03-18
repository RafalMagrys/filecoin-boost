#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

REPO="${POREP_MARKET_REPO:-https://github.com/fidlabs/porep-market.git}"
BRANCH="${POREP_MARKET_BRANCH:-fix-deploy-order}"

command -v forge &>/dev/null || { echo "ERROR: foundry not installed (https://getfoundry.sh)"; exit 1; }

if [ -d "$POREP_DIR" ]; then
    echo "porep-market already cloned, pulling $BRANCH..."
    cd "$POREP_DIR" && git fetch origin && git checkout "$BRANCH" && git pull origin "$BRANCH"
else
    echo "Cloning porep-market ($BRANCH)..."
    git clone --branch "$BRANCH" "$REPO" "$POREP_DIR"
fi

cd "$POREP_DIR"
forge install
forge build

# filecoin-pay (needed for deploy)
FILPAY_DIR="$SCRIPT_DIR/filecoin-pay"
FILPAY_REPO="${FILECOIN_PAY_REPO:-https://github.com/FilOzone/filecoin-pay.git}"

if [ -d "$FILPAY_DIR" ]; then
    cd "$FILPAY_DIR" && git pull origin main 2>/dev/null || true
else
    git clone "$FILPAY_REPO" "$FILPAY_DIR"
fi

cd "$FILPAY_DIR"
forge install 2>/dev/null || true
forge build

echo "Done."
