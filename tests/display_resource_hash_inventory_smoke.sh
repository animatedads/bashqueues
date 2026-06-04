#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/resources.d"
cp -a resources.d/display "$tmpdir/resources.d/display"
cp -a resources.d/xml "$tmpdir/resources.d/xml"
out="$tmpdir/hash-inventory-ok.json"
python3 bin/queue-display-resource-hash-inventory.py --root "$tmpdir" --json > "$out"
python3 - "$out" <<'PY'
import json, re, sys
payload = json.load(open(sys.argv[1]))
assert payload['schema'] == 'queuebash.display_resource_hash_inventory.v1'
assert payload['status'] == 'ok', payload.get('findings')
assert payload['redacted'] is True
assert payload['read_only'] is True
assert payload['installer'] is False
assert payload['signing_mutation'] is False
assert payload['permission_mutation'] is False
assert payload['token_value_substitution'] is False
assert payload['renderer'] == 'none-hash-inventory-only'
assert payload['source'] == 'manifest-listed-files-and-sha256-only'
assert payload['hash_algorithm'] == 'sha256'
assert payload['stats']['manifest_files'] == 2
assert payload['stats']['resource_files'] >= 2
assert payload['stats']['resource_hashes_ok'] == payload['stats']['resource_files']
assert payload['stats']['resource_hashes_missing'] == 0
assert payload['stats']['resource_hashes_error'] == 0
assert payload['manifests']
assert payload['resources']
for item in payload['resources']:
    assert item['hash_status'] == 'ok'
    assert re.fullmatch(r'[0-9a-f]{64}', item['sha256'])
    assert item['path'].startswith('resources.d/')
for text in json.dumps(payload).splitlines():
    assert 'actual-secret' not in text.lower()
    assert 'secret-value' not in text.lower()
PY
rm "$tmpdir/resources.d/display/fallback/queue-version.txt"
if python3 bin/queue-display-resource-hash-inventory.py --root "$tmpdir" --json > "$tmpdir/hash-inventory-missing.json"; then
  echo "expected missing manifest-listed resource to fail" >&2
  exit 1
fi
python3 - "$tmpdir/hash-inventory-missing.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1]))
assert payload['schema'] == 'queuebash.display_resource_hash_inventory.v1'
assert payload['status'] == 'error'
assert payload['stats']['resource_hashes_missing'] >= 1
assert any(f['code'] == 'resource_missing' for f in payload['findings'])
assert any(r['hash_status'] == 'missing' for r in payload['resources'])
PY
