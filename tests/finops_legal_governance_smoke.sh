#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/qroot"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_PLUGIN_SOURCE_DIR="$ROOT/assets.d"
export QUEUEBASH_CAP_PLUGIN_SOURCE_DIR="$ROOT/caps.d"
export QUEUEBASH_CLASS_SOURCE_DIR="$ROOT/classes"
export QUEUEBASH_POLICY_SOURCE_DIR="$ROOT/policies.d"
export QUEUEBASH_REPORTER_PLUGIN_SOURCE_DIR="$ROOT/reporters.d"
source "$ROOT/queuebash.sh"
queue list >/dev/null
fail(){ echo "[FAIL] $*" >&2; exit 1; }

# FinOps anomaly asset: ok, warn allowed when blocking only on error, error blocks.
mkdir -p "$QUEUEBASH_ROOT/streams"
printf '2026-05-26T00:00:00Z finops=ok\n' > "$QUEUEBASH_ROOT/streams/finops.health"
_queue_asset_implied_preflight_args finops:anomaly_free finops anomaly_free _ block_on=error >/dev/null || fail "finops ok should pass"
printf '2026-05-26T00:00:00Z finops=warn\n' > "$QUEUEBASH_ROOT/streams/finops.health"
_queue_asset_implied_preflight_args finops:anomaly_free finops anomaly_free _ block_on=error >/dev/null || fail "finops warn should pass when block_on=error"
if _queue_asset_implied_preflight_args finops:anomaly_free finops anomaly_free _ block_on=warn >/dev/null 2>&1; then
  fail "finops warn should block when block_on=warn"
fi
printf '2026-05-26T00:00:00Z finops=error\n' > "$QUEUEBASH_ROOT/streams/finops.health"
if _queue_asset_implied_preflight_args finops:anomaly_free finops anomaly_free _ block_on=error >/dev/null 2>&1; then
  fail "finops error should block"
fi

# Analyzer writes cache and health atomically enough for assets to consume.
mkdir -p "$QUEUEBASH_ROOT/streams" "$tmp/cache"
python3 - <<'PY' "$QUEUEBASH_ROOT/streams/finops.pricing.jsonl"
import json, sys
path=sys.argv[1]
prices=[0.04,0.041,0.039,0.04,0.20]
with open(path,'w') as f:
    for p in prices:
        f.write(json.dumps({"provider":"gcp","region":"europe-west3","instanceType":"e2-standard-4","market":"spot","price":p})+'\n')
PY
bin/queue-finops-analyze --root "$QUEUEBASH_ROOT" --cache-dir "$tmp/cache" --min-samples 5 --z-warn 1 --z-error 3 >/dev/null || true
[[ -s "$QUEUEBASH_ROOT/streams/finops.health" ]] || fail "finops health not written"
[[ -s "$tmp/cache/queuebash_pricing_europe-west3_e2-standard-4.txt" ]] || fail "finops price cache not written"

# Legal registry-backed checks.
reg="$tmp/legal_registry.tsv"
cat > "$reg" <<'REG'
# id legal_class retention_until jurisdiction_scope destructive_allowed export_allowed
dataset:hold LITIGATION_HOLD 2031-01-01 UK_DPA 0 1
dataset:open NONE - UK_DPA,GDPR 1 1
dataset:noexport NONE - UK_DPA 1 0
REG
_queue_asset_implied_preflight_args legal:retention_respected legal retention_respected dataset:hold registry_file="$reg" effect=readonly allow_user_registry=1 >/dev/null || fail "readonly under hold should pass"
if _queue_asset_implied_preflight_args legal:retention_respected legal retention_respected dataset:hold registry_file="$reg" effect=destructive allow_user_registry=1 >/dev/null 2>&1; then
  fail "destructive under litigation hold should block"
fi
_queue_asset_implied_preflight_args legal:jurisdiction_allowed legal jurisdiction_allowed dataset:hold registry_file="$reg" worker_jurisdiction=UK_DPA allow_user_registry=1 >/dev/null || fail "matching jurisdiction should pass"
if _queue_asset_implied_preflight_args legal:jurisdiction_allowed legal jurisdiction_allowed dataset:hold registry_file="$reg" worker_jurisdiction=US_ITAR allow_user_registry=1 >/dev/null 2>&1; then
  fail "mismatched jurisdiction should block"
fi
if _queue_asset_implied_preflight_args legal:retention_respected legal retention_respected dataset:noexport registry_file="$reg" effect=export allow_user_registry=1 >/dev/null 2>&1; then
  fail "export denied record should block export"
fi

# User-root registry is denied unless explicitly opted in.
user_reg="$QUEUEBASH_ROOT/policies.d/legal_registry.tsv"
mkdir -p "$(dirname "$user_reg")"
cp "$reg" "$user_reg"
if _queue_asset_implied_preflight_args legal:retention_respected legal retention_respected dataset:open registry_file="$user_reg" effect=readonly >/dev/null 2>&1; then
  fail "user-root legal registry should require allow_user_registry=1"
fi

echo '[PASS] FinOps/legal governance smoke checks pass'
