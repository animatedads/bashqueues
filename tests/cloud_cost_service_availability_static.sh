#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
needles=(
  "providers.d/cloud_signals/cloud_signals_provider.sh"
  "docs/CLOUD_COST_SERVICE_AVAILABILITY_WIRING.md"
  "policies.d/cloud-signals/service-availability.example.json"
  "policies.d/cloud-signals/cost-catalog.example.json"
)
for rel in "${needles[@]}"; do
  [[ -f "$ROOT/$rel" ]] || { echo "missing $rel" >&2; exit 1; }
done
bash -n "$ROOT/providers.d/cloud_signals/cloud_signals_provider.sh"
grep -q 'queuebash.cloud_signals.availability.v1' "$ROOT/providers.d/cloud_signals/cloud_signals_provider.sh"
grep -q 'queuebash.cloud_signals.cost.v1' "$ROOT/providers.d/cloud_signals/cloud_signals_provider.sh"
grep -q 'cloud-signals|cloud_signals|cloud-cost|cloud-availability)' "$ROOT/queuebash.sh"
grep -q '_queue_cloud_signals_command' "$ROOT/queuebash.sh"
python3 -m json.tool "$ROOT/policies.d/cloud-signals/service-availability.example.json" >/dev/null
python3 -m json.tool "$ROOT/policies.d/cloud-signals/cost-catalog.example.json" >/dev/null
printf 'PASS cloud_cost_service_availability_static\n'
