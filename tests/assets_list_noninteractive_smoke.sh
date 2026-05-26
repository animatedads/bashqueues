#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export QUEUEBASH_ROOT="$TMP/qroot"
mkdir -p "$QUEUEBASH_ROOT/assets.d"

cat > "$QUEUEBASH_ROOT/assets.d/good.sh" <<'ASSET'
queue_asset_facilities() {
    echo "good:ok Good asset"
}
queue_asset_check_good_ok() {
    echo "asset_check_ok: $1"
}
ASSET

cat > "$QUEUEBASH_ROOT/assets.d/publish_to_github.sh" <<'HELPER'
# This simulates a non-asset helper that would be dangerous to source during listing.
echo "PROMPT_OR_NETWORK_SIDE_EFFECT" >&2
read -r answer
HELPER

out="$(QUEUEBASH_ALLOW_NONINTERACTIVE=1 bash -c "source \"$ROOT/queuebash.sh\" >/dev/null 2>\&1; queue assets list --json" 2>&1)"

if grep -q 'PROMPT_OR_NETWORK_SIDE_EFFECT' <<<"$out"; then
    echo "[FAIL] queue assets list sourced a non-asset helper" >&2
    echo "$out" >&2
    exit 1
fi

if ! grep -q '"facility":"good:ok"' <<<"$out"; then
    echo "[FAIL] valid asset facility missing from json output" >&2
    echo "$out" >&2
    exit 1
fi

if ! grep -q 'not_asset_plugin' <<<"$out"; then
    echo "[FAIL] non-plugin helper was not reported as skipped/invalid" >&2
    echo "$out" >&2
    exit 1
fi

echo "[PASS] queue assets list --json does not source non-plugin helpers"
