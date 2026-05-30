#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$ROOT/providers.d/cloud_signals/cloud_signals_provider.sh"
platforms="$($helper platforms --json)"
printf '%s' "$platforms" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["schema"]=="queuebash.cloud_signals.platforms.v1"; ps={p["provider"] for p in d["platforms"]}; assert {"oci","aws","azure","gcp","ibm"}.issubset(ps)'
avail="$($helper availability-check --provider aws --region eu-west-2 --service compute --json)"
printf '%s' "$avail" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["schema"]=="queuebash.cloud_signals.availability.v1"; assert d["decision"]=="allow"; assert d["live"] is False'
cost_ok="$($helper cost-check --provider aws --region eu-west-2 --service compute --estimated-hourly-usd 0.50 --monthly-budget-usd 750 --json)"
printf '%s' "$cost_ok" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["schema"]=="queuebash.cloud_signals.cost.v1"; assert d["decision"]=="allow"; assert d["estimated_monthly_usd"]==365.0'
cost_bad="$($helper cost-check --provider aws --region eu-west-2 --service compute --estimated-hourly-usd 10 --monthly-budget-usd 100 --json)"
printf '%s' "$cost_bad" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["decision"]=="deny"; assert any(g["decision"]=="deny" for g in d["gates"])'
explain="$($helper explain --provider oci --region uk-london-1 --service compute --estimated-hourly-usd 0.50 --monthly-budget-usd 750 --json)"
printf '%s' "$explain" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["schema"]=="queuebash.cloud_signals.explain.v1"; assert d["decision"]=="allow"; assert d["mutated"] is False'
# queue dispatch alias smoke
QUEUEBASH_ALLOW_NONINTERACTIVE=1 bash -lc "source '$ROOT/queuebash.sh'; queue cloud-signals availability-check --provider gcp --region europe-west2 --service compute --json" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["schema"]=="queuebash.cloud_signals.availability.v1"; assert d["provider"]=="gcp"'
printf 'PASS cloud_cost_service_availability_smoke\n'
