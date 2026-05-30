#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
fail(){ echo "[FAIL] $*" >&2; exit 1; }

provider="providers.d/grid_energy/grid_energy_provider.sh"
asset="assets.d/grid_energy.sh"
cheap="tests/fixtures/grid_energy/allow_cheap_green.json"
expensive="tests/fixtures/grid_energy/deny_expensive.json"
negative="tests/fixtures/grid_energy/allow_negative.json"

out="$($provider explain --json)"
grep -q '"schema": "queuebash.grid_energy.provider.v1"\|"schema":"queuebash.grid_energy.provider.v1"' <<<"$out" || fail 'explain json schema missing'
grep -q '"live_call_performed": false\|"live_call_performed":false' <<<"$out" || fail 'explain must prove no live call'

allow="$($provider evaluate --cache "$cheap" --market uk_eso --zone GB --max-price-per-kwh 0.15 --max-carbon-gco2-kwh 120 --max-age-seconds 999999999 --json)"
grep -q '"decision": "allow"\|"decision":"allow"' <<<"$allow" || fail 'cheap/green fixture should allow'

set +e
deny="$($provider evaluate --cache "$expensive" --market uk_eso --zone GB --max-price-per-kwh 0.15 --max-age-seconds 999999999 --json 2>/dev/null)"
deny_rc=$?
set -e
[[ "$deny_rc" -ne 0 ]] || fail 'expensive fixture should deny'
grep -q '"decision": "deny"\|"decision":"deny"' <<<"$deny" || fail 'expensive fixture deny json missing'
grep -q 'price_above_threshold' <<<"$deny" || fail 'expensive fixture reason missing'

neg="$($provider evaluate --cache "$negative" --market nordpool --zone SE3 --require-negative-price --max-age-seconds 999999999 --json)"
grep -q '"decision": "allow"\|"decision":"allow"' <<<"$neg" || fail 'negative-price fixture should allow'

bash -c "source '$asset'; queue_asset_check_grid_energy_price_below tok 0.15 cache_file='$cheap' market=uk_eso zone=GB max_age_seconds=999999999 provider_script='$provider'" > /tmp/grid_energy_asset_price.out
grep -q 'asset_check_ok: tok' /tmp/grid_energy_asset_price.out || fail 'asset price_below should pass'

set +e
bash -c "source '$asset'; queue_asset_check_grid_energy_price_below tok 0.15 cache_file='$expensive' market=uk_eso zone=GB max_age_seconds=999999999 provider_script='$provider'" > /tmp/grid_energy_asset_price_bad.out 2>&1
bad_rc=$?
set -e
[[ "$bad_rc" -ne 0 ]] || fail 'asset price_below should block expensive fixture'
grep -q 'asset_check_blocked: grid_energy:price_below' /tmp/grid_energy_asset_price_bad.out || fail 'asset blocked message missing'

bash -c "source '$asset'; queue_asset_check_grid_energy_negative_price tok SE3 cache_file='$negative' market=nordpool zone=SE3 max_age_seconds=999999999 provider_script='$provider'" > /tmp/grid_energy_asset_negative.out
grep -q 'asset_check_ok: tok' /tmp/grid_energy_asset_negative.out || fail 'asset negative_price should pass'

echo '[PASS] grid energy provider fixture smoke passes'
