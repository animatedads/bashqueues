#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/cloud_resource/provider_parity_report.py"
tmp="${TMPDIR:-/tmp}/provider-parity-report.$$"
trap 'rm -f "$tmp.json" "$tmp.txt"' EXIT

"$helper" --root . > "$tmp.txt"
grep -q 'Provider parity report' "$tmp.txt"
grep -q 'live API calls: false' "$tmp.txt"

"$helper" --root . --json --fail-on-missing > "$tmp.json"
python3 - "$tmp.json" <<'PY'
import json, sys
obj=json.load(open(sys.argv[1]))
assert obj['schema']=='queuebash.provider_parity_report.v1'
assert obj['live_api_calls'] is False
assert obj['credentials_required'] is False
assert obj['cloud_mutation'] is False
assert obj['queue_dispatch_refactor'] is False
assert obj['summary']['families_total'] >= 10
assert obj['summary']['families_incomplete'] == 0, obj['summary']
families={row['id']: row for row in obj['families']}
for key in ['aws','azure','gcp','oci','ibm','eu_sovereign','apac_china','gpu_cloud','edge_cloud','hybrid_onprem']:
    assert key in families, key
    assert families[key]['complete'] is True, key
    assert families[key]['decision'] == 'allow', key
assert families['aws']['status'] == 'first_tier_contract_coverage'
assert families['edge_cloud']['status'] == 'fixture_first_mapped_pending_validation'
print('PASS provider parity report json')
PY

"$helper" --root . --family aws --json > "$tmp.json"
python3 - "$tmp.json" <<'PY'
import json, sys
obj=json.load(open(sys.argv[1]))
assert obj['summary']['families_total'] == 1
assert obj['families'][0]['id'] == 'aws'
print('PASS provider parity family filter')
PY

echo 'PASS provider_parity_report_smoke'
