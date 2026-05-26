#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! grep -q '_queue_asset_plugin_looks_like_plugin' queuebash.sh; then
    echo "[FAIL] missing asset plugin prefilter" >&2
    exit 1
fi

if ! grep -q 'QUEUEBASH_ASSET_DISCOVERY=1' queuebash.sh; then
    echo "[FAIL] asset discovery should set noninteractive discovery marker" >&2
    exit 1
fi

if ! grep -q 'exec </dev/null' queuebash.sh; then
    echo "[FAIL] asset discovery should detach stdin before sourcing plugins" >&2
    exit 1
fi

echo "[PASS] asset listing is guarded against non-plugin/prompting helper scripts"
