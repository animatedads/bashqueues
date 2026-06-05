#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
trap 'rm -rf "$QUEUEBASH_ROOT"' EXIT
source ./queuebash.sh
queue submit alpha --class DEFAULT -- echo alpha >/dev/null
queue submit beta --class DEFAULT -- echo beta >/dev/null
queue explain DEFAULT --json > /tmp/explain-class.json
python3 - <<'PY'
import json
rec=json.load(open('/tmp/explain-class.json'))
assert rec['schema']=='queuebash.explain.multi.v1', rec
assert rec['query']=='DEFAULT', rec
assert rec['query_type']=='class', rec
assert rec['matched_count']==2, rec
assert {r['name'] for r in rec['records']} == {'alpha','beta'}, rec
PY
echo 'PASS explain_class_json_multi_smoke'
