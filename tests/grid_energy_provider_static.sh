#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -Eq 'QUEUEBASH_VERSION="0\.18\.[0-9]+"' queuebash.sh || fail 'QUEUEBASH_VERSION shape missing'
[[ -x providers.d/grid_energy/grid_energy_provider.sh ]] || fail 'grid energy provider missing/not executable'
[[ -x assets.d/grid_energy.sh ]] || fail 'grid energy asset missing/not executable'
bash -n providers.d/grid_energy/grid_energy_provider.sh || fail 'provider syntax'
bash -n assets.d/grid_energy.sh || fail 'asset syntax'

for f in \
  docs/GRID_ENERGY_COST_MODEL.md \
  docs/GRID_ENERGY_PROVIDER_CONTRACT.md \
  policies.d/grid-energy/default.env.example \
  policies.d/grid-energy/markets.tsv.example \
  classes/ENERGY_AWARE_BATCH.env \
  classes/ENERGY_NEGATIVE_PRICE_BATCH.env; do
  [[ -f "$f" ]] || fail "missing $f"
done

grep -q 'grid_energy:price_below' assets.d/grid_energy.sh || fail 'price facility missing'
grep -q 'grid_energy:carbon_below' assets.d/grid_energy.sh || fail 'carbon facility missing'
grep -q 'grid_energy:negative_price' assets.d/grid_energy.sh || fail 'negative price facility missing'
grep -q 'live_call_performed' providers.d/grid_energy/grid_energy_provider.sh || fail 'provider must expose no-live evidence'
grep -q 'mutation_performed' providers.d/grid_energy/grid_energy_provider.sh || fail 'provider must expose no-mutation evidence'
grep -q 'OPC UA, SCADA, Kepware, MQTT' docs/GRID_ENERGY_COST_MODEL.md || fail 'OT/ICS boundary missing'
grep -q 'QUEUEBASH_GRID_ENERGY_LIVE_API_ENABLED=0' policies.d/grid-energy/default.env.example || fail 'live API default gate missing'
grep -q 'QUEUEBASH_GRID_ENERGY_OT_WRITE_ENABLED=0' policies.d/grid-energy/default.env.example || fail 'OT write default gate missing'
[[ ! -e assets.d/net_usage.sh ]] || fail 'assets.d/net_usage.sh must remain absent'

echo '[PASS] grid energy provider static checks pass'
