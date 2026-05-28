#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "FAIL $*" >&2; exit 1; }

[[ -f assets.d/ibm_finops.sh ]] || fail 'missing assets.d/ibm_finops.sh'
bash -n assets.d/ibm_finops.sh || fail 'ibm finops asset syntax'
grep -q 'ibm_finops:cost_cache_fresh' assets.d/ibm_finops.sh || fail 'missing cost_cache_fresh facility'
grep -q 'ibm_finops:budget_remaining' assets.d/ibm_finops.sh || fail 'missing budget_remaining facility'
grep -q 'ibm_finops:spend_below' assets.d/ibm_finops.sh || fail 'missing spend_below facility'
grep -q 'ibm_finops:anomaly_free' assets.d/ibm_finops.sh || fail 'missing anomaly_free facility'
grep -q '/etc/queuebash/finops/ibm_cost_cache.json' assets.d/ibm_finops.sh || fail 'missing canonical cache path'
grep -q 'QUEUEBASH_IBM_FINOPS_CACHE' assets.d/ibm_finops.sh || fail 'missing cache override env'
grep -q 'does not implement live IBM API calls\|never calls IBM Cloud APIs' assets.d/ibm_finops.sh || fail 'asset must state no worker-side live API calls'
grep -q 'QUEUEBASH_VERSION="0.18.22"' queuebash.sh || fail 'version not bumped to 0.18.22'

# Smoke the asset against local cache files only.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
now="$(date +%s)"
cat > "$tmp/ibm_cost_cache.json" <<JSON
{
  "schema": "queuebash.ibm_finops_cache.v1",
  "generated_at_epoch": $now,
  "provider": "ibm",
  "region": "eu-gb",
  "spend": { "account": { "month": 123.45 } },
  "budgets": { "ibm-finreg": { "remaining": 2500.0 } }
}
JSON
printf 'severity=ok\n' > "$tmp/ibm_finops.health"

bash -c "
  source assets.d/ibm_finops.sh
  queue_asset_check_ibm_finops_cost_cache_fresh tok account cache_file=$tmp/ibm_cost_cache.json allow_user_cache=1 max_age_seconds=86400 >/tmp/ibm_finops_fresh.out
  queue_asset_check_ibm_finops_budget_remaining tok ibm-finreg cache_file=$tmp/ibm_cost_cache.json allow_user_cache=1 min_remaining=100 >/tmp/ibm_finops_budget.out
  queue_asset_check_ibm_finops_spend_below tok account cache_file=$tmp/ibm_cost_cache.json allow_user_cache=1 period=month max_spend=200 >/tmp/ibm_finops_spend.out
  queue_asset_check_ibm_finops_anomaly_free tok account health_file=$tmp/ibm_finops.health allow_user_cache=1 block_on=error >/tmp/ibm_finops_health.out
"

grep -q 'asset_check_ok: tok' /tmp/ibm_finops_fresh.out || fail 'fresh cache did not pass'
grep -q 'asset_check_ok: tok' /tmp/ibm_finops_budget.out || fail 'budget did not pass'
grep -q 'asset_check_ok: tok' /tmp/ibm_finops_spend.out || fail 'spend did not pass'
grep -q 'asset_check_ok: tok' /tmp/ibm_finops_health.out || fail 'health did not pass'

set +e
bash -c "
  source assets.d/ibm_finops.sh
  queue_asset_check_ibm_finops_budget_remaining tok ibm-finreg cache_file=$tmp/ibm_cost_cache.json allow_user_cache=1 min_remaining=9999 >/tmp/ibm_finops_budget_bad.out 2>&1
"
bad_rc=$?
set -e
[[ "$bad_rc" -ne 0 ]] || fail 'budget should block when remaining is too low'
grep -q 'asset_check_blocked: ibm_finops:budget_remaining' /tmp/ibm_finops_budget_bad.out || fail 'bad budget did not emit blocked message'

printf 'severity=error\n' > "$tmp/ibm_finops.health"
set +e
bash -c "
  source assets.d/ibm_finops.sh
  queue_asset_check_ibm_finops_anomaly_free tok account health_file=$tmp/ibm_finops.health allow_user_cache=1 block_on=error >/tmp/ibm_finops_health_bad.out 2>&1
"
bad_health_rc=$?
set -e
[[ "$bad_health_rc" -ne 0 ]] || fail 'health should block on error severity'
grep -q 'asset_check_blocked: ibm_finops:anomaly_free' /tmp/ibm_finops_health_bad.out || fail 'bad health did not emit blocked message'

echo "PASS tests/ibm_finops_asset_static.sh"
