#!/usr/bin/env bash
# queuebash grid-energy provider
# Fixture/cache-first Grid FinOps helper. It never calls live grid, market, carbon,
# SCADA, OPC UA, MQTT, or cloud APIs. A separate approved collector may refresh the
# cache; this provider only evaluates local JSON evidence.
set -euo pipefail

_grid_energy_usage() {
  cat <<'USAGE'
Usage:
  grid_energy_provider.sh explain [--json]
  grid_energy_provider.sh evaluate --cache FILE [--market NAME] [--zone ZONE]
      [--max-price-per-kwh VALUE] [--max-carbon-gco2-kwh VALUE]
      [--require-negative-price] [--max-age-seconds SEC] [--json]

Local cache schema: queuebash.grid_energy_observation.v1
Default behaviour is fail-closed when cache data is missing, stale, malformed,
or above the configured price/carbon threshold. This helper performs no live API
calls and no industrial control writes.
USAGE
}

_grid_energy_json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read())[1:-1])'
}

_grid_energy_eval() {
  python3 - "$@" <<'PY'
import argparse, json, pathlib, sys, time
ap = argparse.ArgumentParser()
ap.add_argument('--cache', required=True)
ap.add_argument('--market', default='')
ap.add_argument('--zone', default='')
ap.add_argument('--max-price-per-kwh', type=float)
ap.add_argument('--max-carbon-gco2-kwh', type=float)
ap.add_argument('--require-negative-price', action='store_true')
ap.add_argument('--max-age-seconds', type=int, default=900)
ap.add_argument('--json', action='store_true')
ns = ap.parse_args()

def out(obj):
    print(json.dumps(obj, sort_keys=True))

def deny(reason, **extra):
    obj = {
        'schema': 'queuebash.grid_energy.decision.v1',
        'decision': 'deny',
        'reason': reason,
        'live_call_performed': False,
        'mutation_performed': False,
        'advisory_only': True,
    }
    obj.update(extra)
    out(obj)
    return 1

path = pathlib.Path(ns.cache)
if not path.is_file():
    raise SystemExit(deny('cache_missing', cache=str(path)))
try:
    doc = json.loads(path.read_text(encoding='utf-8'))
except Exception as exc:
    raise SystemExit(deny('cache_invalid_json', error=exc.__class__.__name__))
if doc.get('schema') != 'queuebash.grid_energy_observation.v1':
    raise SystemExit(deny('cache_bad_schema', schema=doc.get('schema')))
if ns.market and str(doc.get('market','')).lower() != ns.market.lower():
    raise SystemExit(deny('market_mismatch', expected=ns.market, actual=doc.get('market')))
if ns.zone and str(doc.get('zone','')).lower() != ns.zone.lower():
    raise SystemExit(deny('zone_mismatch', expected=ns.zone, actual=doc.get('zone')))
now = int(time.time())
observed = int(doc.get('observed_at_epoch') or doc.get('generated_at_epoch') or 0)
age = now - observed if observed else 10**12
if age < 0:
    age = 0
if ns.max_age_seconds >= 0 and age > ns.max_age_seconds:
    raise SystemExit(deny('cache_stale', age_seconds=age, max_age_seconds=ns.max_age_seconds))
try:
    price = float(doc.get('price_per_kwh'))
except Exception:
    raise SystemExit(deny('price_missing_or_invalid'))
carbon_raw = doc.get('carbon_gco2_kwh')
carbon = None
if carbon_raw is not None:
    try:
        carbon = float(carbon_raw)
    except Exception:
        raise SystemExit(deny('carbon_invalid'))
if ns.max_price_per_kwh is not None and price > ns.max_price_per_kwh:
    raise SystemExit(deny('price_above_threshold', price_per_kwh=price, max_price_per_kwh=ns.max_price_per_kwh, age_seconds=age))
if ns.require_negative_price and price >= 0:
    raise SystemExit(deny('price_not_negative', price_per_kwh=price, age_seconds=age))
if ns.max_carbon_gco2_kwh is not None:
    if carbon is None:
        raise SystemExit(deny('carbon_missing'))
    if carbon > ns.max_carbon_gco2_kwh:
        raise SystemExit(deny('carbon_above_threshold', carbon_gco2_kwh=carbon, max_carbon_gco2_kwh=ns.max_carbon_gco2_kwh, age_seconds=age))
obj = {
    'schema': 'queuebash.grid_energy.decision.v1',
    'decision': 'allow',
    'reason': 'grid_energy_policy_pass',
    'market': doc.get('market'),
    'zone': doc.get('zone'),
    'price_per_kwh': price,
    'carbon_gco2_kwh': carbon,
    'age_seconds': age,
    'source': doc.get('source','local_cache'),
    'live_call_performed': False,
    'mutation_performed': False,
    'advisory_only': True,
}
out(obj)
PY
}

cmd="${1:-}"
shift || true
case "$cmd" in
  explain)
    json=0
    while [[ "$#" -gt 0 ]]; do
      case "$1" in --json) json=1; shift ;; --help|-h) _grid_energy_usage; exit 0 ;; *) echo "grid_energy_provider: unexpected argument: $1" >&2; exit 2 ;; esac
    done
    if [[ "$json" -eq 1 ]]; then
      printf '{"schema":"queuebash.grid_energy.provider.v1","provider":"grid_energy","fixture_first":true,"live_call_performed":false,"mutation_performed":false,"supported_markets":["ercot","nordpool","entsoe","uk_eso","custom"],"decisions":["allow","deny"]}\n'
    else
      echo 'grid_energy provider: fixture/cache-first local Grid FinOps evaluator'
      echo 'live calls: no; mutations: no; worker preflight reads local JSON cache only'
    fi
    ;;
  evaluate)
    _grid_energy_eval "$@"
    ;;
  --help|-h|help|'')
    _grid_energy_usage
    ;;
  *)
    echo "grid_energy_provider: unknown command: $cmd" >&2
    _grid_energy_usage >&2
    exit 2
    ;;
esac
