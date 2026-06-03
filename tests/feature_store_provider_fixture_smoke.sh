#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
export QUEUEBASH_FEATURE_STORE_FIXTURE_DIR="$ROOT/tests/fixtures/feature_store"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
for cmd in "detect" "entity explain" "feature-view explain" "training-set explain" "lineage explain"; do
  providers.d/feature_store/feature_store_provider.sh $cmd >>"$tmp"
  printf '
' >>"$tmp"
done
unset QUEUEBASH_FEATURE_STORE_FIXTURE_DIR
providers.d/feature_store/feature_store_provider.sh entity explain >>"$tmp"
python3 - "$tmp" <<'PYFEA'
import json, sys
text=open(sys.argv[1], encoding='utf-8').read()
dec=json.JSONDecoder(); idx=0; records=[]
while idx < len(text):
    while idx < len(text) and text[idx].isspace(): idx += 1
    if idx >= len(text): break
    obj, end = dec.raw_decode(text, idx); records.append(obj); idx = end
assert len(records) == 6, len(records)
for obj in records[:-1]:
    assert obj.get('provider_family') == 'feature_store', obj
    assert obj.get('decision') in ('allow','deny'), obj
    assert obj.get('mutated', False) is False, obj
last=records[-1]
assert last['decision'] == 'deny', last
assert last['fail_closed'] is True, last
PYFEA
echo 'PASS feature_store_provider_fixture_smoke'
