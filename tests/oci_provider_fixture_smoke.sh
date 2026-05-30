#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/oci/oci_provider.sh"
fixture="tests/fixtures/oci"

run_json(){ QUEUEBASH_OCI_FIXTURE_DIR="$fixture" "$helper" "$@"; }

run_json detect > /tmp/oci_detect.$$.json
run_json metadata > /tmp/oci_metadata.$$.json
run_json identity explain > /tmp/oci_identity.$$.json
run_json region explain > /tmp/oci_region.$$.json
run_json object-storage explain > /tmp/oci_object.$$.json
run_json network explain > /tmp/oci_network.$$.json
run_json resource-shape explain > /tmp/oci_shape.$$.json

/usr/bin/python3 - /tmp/oci_detect.$$.json /tmp/oci_metadata.$$.json /tmp/oci_identity.$$.json /tmp/oci_region.$$.json /tmp/oci_object.$$.json /tmp/oci_network.$$.json /tmp/oci_shape.$$.json <<'PY'
import json, sys
expected = [
    'queuebash.oci.detect.v1',
    'queuebash.oci.metadata.v1',
    'queuebash.oci.identity.v1',
    'queuebash.oci.region.v1',
    'queuebash.oci.object_storage.v1',
    'queuebash.oci.network.v1',
    'queuebash.oci.resource_shape.v1',
]
for path, schema in zip(sys.argv[1:], expected):
    with open(path, encoding='utf-8') as f:
        data = json.load(f)
    assert data.get('schema') == schema, (path, data.get('schema'), schema)
    assert data.get('provider') == 'oci', path
    if 'decision' in data:
        assert data['decision'] in ('allow', 'available', 'deny', 'unknown'), path
    if schema == 'queuebash.oci.detect.v1':
        assert data.get('auth_header_required') is True
    if schema == 'queuebash.oci.object_storage.v1':
        assert data.get('par_url_redacted') is True
print('PASS oci fixture json')
PY

rm -f /tmp/oci_detect.$$.json /tmp/oci_metadata.$$.json /tmp/oci_identity.$$.json /tmp/oci_region.$$.json /tmp/oci_object.$$.json /tmp/oci_network.$$.json /tmp/oci_shape.$$.json

echo 'PASS oci_provider_fixture_smoke'
