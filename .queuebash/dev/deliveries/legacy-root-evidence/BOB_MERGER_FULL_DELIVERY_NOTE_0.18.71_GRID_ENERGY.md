# 0.18.71 BOB_MERGER grid energy cost model contract merge

Folded Bob11's 0.18.69 grid energy cost model branch payload onto the accepted 0.18.70 cloud cost/service-availability base.

## Merger decision

- Runtime version: `QUEUEBASH_VERSION="0.18.71"`
- Incoming Bob11 `0.18.69` is branch identity only.
- The payload adds real grid-energy provider/asset/class/test surface and lands after the accepted 0.18.70 base.

## Added

- `assets.d/grid_energy.sh`
- `providers.d/grid_energy/grid_energy_provider.sh`
- `classes/ENERGY_AWARE_BATCH.env`
- `classes/ENERGY_NEGATIVE_PRICE_BATCH.env`
- `docs/GRID_ENERGY_COST_MODEL.md`
- `docs/GRID_ENERGY_PROVIDER_CONTRACT.md`
- `policies.d/grid-energy/*.example`
- `tests/fixtures/grid_energy/*.json`
- `tests/grid_energy_provider_*`

## Boundary

- No live grid API calls.
- No credentials.
- No OT/ICS writes.
- No provisioning/destruction.
- No queue dispatch refactor.
