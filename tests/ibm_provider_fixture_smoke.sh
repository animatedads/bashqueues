#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/ibm/ibm_provider.sh"
fixture="tests/fixtures/ibm"

run_json(){ QUEUEBASH_IBM_FIXTURE_DIR="$fixture" "$helper" "$@"; }

run_json detect       > /tmp/ibm_detect.$$.json
run_json identity explain > /tmp/ibm_identity.$$.json
run_json region explain   > /tmp/ibm_region.$$.json
run_json resource explain > /tmp/ibm_resource.$$.json
run_json network explain  > /tmp/ibm_network.$$.json
run_json finops explain   > /tmp/ibm_finops.$$.json
run_json legal explain    > /tmp/ibm_legal.$$.json

/usr/bin/python3 - \
  /tmp/ibm_detect.$$.json \
  /tmp/ibm_identity.$$.json \
  /tmp/ibm_region.$$.json \
  /tmp/ibm_resource.$$.json \
  /tmp/ibm_network.$$.json \
  /tmp/ibm_finops.$$.json \
  /tmp/ibm_legal.$$.json <<'PY'
import json, sys
expected = [
    'queuebash.ibm.detect.v1',
    'queuebash.ibm.identity.v1',
    'queuebash.ibm.region.v1',
    'queuebash.ibm.resource.v1',
    'queuebash.ibm.network.v1',
    'queuebash.ibm.finops.v1',
    'queuebash.ibm.legal.v1',
]
for path, schema in zip(sys.argv[1:], expected):
    with open(path, encoding='utf-8') as f:
        data = json.load(f)
    assert data.get('schema') == schema, (path, data.get('schema'), schema)
    assert data.get('provider') == 'ibm', (path, 'provider must be ibm')
    if 'decision' in data:
        assert data['decision'] in ('allow', 'available', 'deny', 'unknown'), \
            (path, 'unexpected decision', data['decision'])
    if schema == 'queuebash.ibm.detect.v1':
        assert data.get('detected') is True, path
        assert 'account_id' in data, path
        assert 'region' in data, path
    if schema == 'queuebash.ibm.identity.v1':
        assert 'auth_method' in data, path
        assert data.get('fail_closed') is True, path
    if schema == 'queuebash.ibm.region.v1':
        assert 'sovereignty_zone' in data, path
        assert isinstance(data.get('legal_frameworks'), list), path
    if schema == 'queuebash.ibm.finops.v1':
        assert 'budget_remaining' in data, path
        assert data.get('anomaly_detected') is False, path
    if schema == 'queuebash.ibm.legal.v1':
        assert 'validation_status' in data, path
print('PASS ibm fixture json')
PY

rm -f /tmp/ibm_detect.$$.json /tmp/ibm_identity.$$.json /tmp/ibm_region.$$.json \
      /tmp/ibm_resource.$$.json /tmp/ibm_network.$$.json \
      /tmp/ibm_finops.$$.json /tmp/ibm_legal.$$.json

echo 'PASS ibm_provider_fixture_smoke'
