#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
fail() { echo "[FAIL] $*" >&2; exit 1; }

for f in assets.d/sovereign.sh assets.d/finops.sh assets.d/gcp.sh assets.d/azure.sh reporters.d/prom.sh; do
  [[ -f "$f" ]] || fail "missing $f"
  bash -n "$f" || fail "bash -n failed for $f"
  if [[ "$f" == assets.d/* ]]; then
    grep -q '^queue_asset_facilities()' "$f" || fail "$f missing queue_asset_facilities"
    grep -q '^queue_asset_hints()' "$f" || fail "$f missing queue_asset_hints"
    grep -q 'queue_asset_check_' "$f" || fail "$f missing checks"
  else
    grep -q '^queue_reporter_facilities()' "$f" || fail "$f missing queue_reporter_facilities"
    grep -q '^queue_reporter_handle_event()' "$f" || fail "$f missing queue_reporter_handle_event"
  fi
done

for f in \
  classes/CLOUD_COMPUTE_GDPR.env \
  classes/CLOUD_COMPUTE_ITAR.env \
  classes/CLOUD_GCP_GDPR.env \
  classes/CLOUD_AZURE_GDPR.env \
  classes/CLOUD_AZURE_UK_DPA.env; do
  [[ -f "$f" ]] || fail "missing $f"
  bash -n "$f" || fail "bash -n failed for $f"
done

[[ -f policies.d/legal_framework.env ]] || fail "missing legal_framework.env"
[[ -f policies.d/legal-framework/default.env ]] || fail "missing legal-framework/default.env"
grep -q 'LEGAL_FRAMEWORK_GDPR_REGIONS' policies.d/legal_framework.env || fail "GDPR mapping missing"
grep -q 'europe-west3' policies.d/legal_framework.env || fail "GCP GDPR region missing"
grep -q 'germanywestcentral' policies.d/legal_framework.env || fail "Azure GDPR region missing"
grep -q 'eu-west-2' policies.d/legal_framework.env || fail "UK/AWS London region missing"

grep -q 'azure:auth_active' assets.d/azure.sh || fail "azure:auth_active facility missing"
grep -q 'queue_asset_check_azure_auth_active' assets.d/azure.sh || fail "azure auth check missing"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
out="$(QUEUEBASH_ROOT="$tmp/qroot" QUEUEBASH_ALLOW_NONINTERACTIVE=1 QUEUEBASH_PLUGIN_SOURCE_DIR="$ROOT/assets.d" bash -c 'source ./queuebash.sh >/dev/null; queue assets list --json')"
for facility in \
  sovereign:framework_allowed sovereign:region_in \
  finops:spot_price_below finops:budget_remaining \
  gcp:auth_active gcp:project_active gcp:region_allowed \
  azure:auth_active; do
  grep -q '"facility":"'"$facility"'"' <<<"$out" || fail "missing asset facility in JSON: $facility"
done

rout="$(QUEUEBASH_ROOT="$tmp/qroot2" QUEUEBASH_ALLOW_NONINTERACTIVE=1 QUEUEBASH_REPORTER_PLUGIN_SOURCE_DIR="$ROOT/reporters.d" bash -c 'source ./queuebash.sh >/dev/null; queue reporters list --json')"
grep -q '"facility":"prom:textfile"' <<<"$rout" || fail "missing prom reporter in JSON"

if grep -qiE 'authenticity of host|are you sure you want to continue|asset_check_blocked|asset_check_ok' <<<"$out$rout"; then
  fail "metadata listing executed live checks or prompted"
fi

[[ ! -e assets.d/net_usage.sh ]] || fail "assets.d/net_usage.sh must remain absent"
echo '[PASS] cloud sovereignty/FinOps assets, classes, policy and reporter metadata are present'
