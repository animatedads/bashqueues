#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/qroot"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_PLUGIN_SOURCE_DIR="$ROOT/assets.d"
export QUEUEBASH_POLICY_SOURCE_DIR="$ROOT/policies.d"
source "$ROOT/queuebash.sh"
queue list >/dev/null

stream="$tmp/events.jsonl"
out="$(_queue_asset_implied_preflight_args audit:stream_verified audit stream_verified Official stream_file="$stream" require_auditd=0 require_remote=0)"
grep -q 'asset_check_ok' <<<"$out"

marker="$tmp/data/.queuebash-encrypted"
mkdir -p "$tmp/data"
touch "$marker"
out="$(_queue_asset_implied_preflight_args crypto:volume_encrypted crypto volume_encrypted "$tmp/data" allow_marker="$marker")"
grep -q 'asset_check_ok' <<<"$out"

export QUEUEBASH_EGRESS_POLICY=deny-all
out="$(_queue_asset_implied_preflight_args net:egress_policy net egress_policy deny-all)"
grep -q 'asset_check_ok' <<<"$out"

export QUEUEBASH_EGRESS_POLICY=public-ok
if _queue_asset_implied_preflight_args net:egress_policy net egress_policy deny-all >/dev/null 2>&1; then
  echo '[FAIL] deny-all egress unexpectedly passed public-ok worker' >&2
  exit 1
fi

echo '[PASS] audit, crypto volume, and egress governance assets smoke checks pass'
