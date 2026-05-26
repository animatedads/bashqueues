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

# Sovereignty passes/fails based on explicit policy and worker region.
export QUEUEBASH_CLOUD_REGION="europe-west3"
out="$(_queue_asset_implied_preflight_args sovereign:framework_allowed sovereign framework_allowed GDPR policy_file="$ROOT/policies.d/legal_framework.env")"
grep -q 'asset_check_ok' <<<"$out"
export QUEUEBASH_CLOUD_REGION="us-central1"
if _queue_asset_implied_preflight_args sovereign:framework_allowed sovereign framework_allowed GDPR policy_file="$ROOT/policies.d/legal_framework.env" >/dev/null 2>&1; then
  echo '[FAIL] sovereignty check unexpectedly passed for us-central1/GDPR' >&2
  exit 1
fi

# FinOps uses a local cache and floating point comparison.
export QUEUEBASH_CLOUD_REGION="eu-west-2"
export QUEUEBASH_CLOUD_INSTANCE_TYPE="m5.large"
price_cache="$tmp/price.txt"
printf '0.04\n' > "$price_cache"
out="$(_queue_asset_implied_preflight_args finops:spot_price_below finops spot_price_below 0.08 cache_file="$price_cache")"
grep -q 'asset_check_ok' <<<"$out"
printf '0.12\n' > "$price_cache"
if _queue_asset_implied_preflight_args finops:spot_price_below finops spot_price_below 0.08 cache_file="$price_cache" >/dev/null 2>&1; then
  echo '[FAIL] finops check unexpectedly passed for high price' >&2
  exit 1
fi

# Prom reporter only writes when explicitly enabled and directory exists.
mkdir -p "$tmp/prom"
export QUEUEBASH_REPORTERS=prom
export QUEUEBASH_REPORTING_SYNC=1
export QUEUEBASH_PROM_DIR="$tmp/prom"
_queue_log_event "unit_event" "qid1" "job-one" "failed" "detail=cloud"
grep -q 'bashqueues_event_last_info' "$tmp/prom/bashqueues_events.prom"
grep -q 'job-one' "$tmp/prom/bashqueues_events.prom"

[[ ! -e "$ROOT/assets.d/net_usage.sh" ]]
echo '[PASS] sovereignty, FinOps, and Prometheus reporter smoke checks pass'
