#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fail(){ echo "[FAIL] $*" >&2; exit 1; }

[[ -x "$ROOT/assets.d/integrity.sh" ]] || fail "integrity asset missing or not executable"
[[ -f "$ROOT/classes/IMMUTABLE_PAYLOAD.env" ]] || fail "IMMUTABLE_PAYLOAD class missing"
[[ -f "$ROOT/docs/INTEGRITY_ASSETS.md" ]] || fail "integrity docs missing"
[[ ! -e "$ROOT/assets.d/net_usage.sh" ]] || fail "assets.d/net_usage.sh must remain absent"

grep -q '^integrity:file_sha256' <(bash -lc "source '$ROOT/assets.d/integrity.sh'; queue_asset_facilities") || fail "file_sha256 facility missing"
grep -q '^integrity:manifest_verified' <(bash -lc "source '$ROOT/assets.d/integrity.sh'; queue_asset_facilities") || fail "manifest_verified facility missing"
grep -q '^integrity:tree_manifest_verified' <(bash -lc "source '$ROOT/assets.d/integrity.sh'; queue_asset_facilities") || fail "tree_manifest_verified facility missing"

bash -n "$ROOT/assets.d/integrity.sh" "$ROOT/classes/IMMUTABLE_PAYLOAD.env"

export QUEUEBASH_ROOT="$(mktemp -d)/q"
trap 'rm -rf "${QUEUEBASH_ROOT%/q}"' EXIT
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
mkdir -p "$QUEUEBASH_ROOT/assets.d"
cp "$ROOT/assets.d/integrity.sh" "$QUEUEBASH_ROOT/assets.d/integrity.sh"
source "$ROOT/queuebash.sh"
queue assets validate >/dev/null || fail "asset contract validation failed"

echo '[PASS] integrity asset static checks pass'
