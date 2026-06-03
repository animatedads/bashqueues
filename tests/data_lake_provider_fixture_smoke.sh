#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
export QUEUEBASH_DATA_LAKE_FIXTURE_DIR="$ROOT/tests/fixtures/data_lake"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
for cmd in "detect" "catalog explain" "dataset explain" "governance explain" "retention explain"; do
  providers.d/data_lake/data_lake_provider.sh $cmd >>"$tmp"
  printf '
' >>"$tmp"
done
unset QUEUEBASH_DATA_LAKE_FIXTURE_DIR
providers.d/data_lake/data_lake_provider.sh dataset explain >>"$tmp"
python3 - "$tmp" <<'PYLAKE'
import json, sys
text=open(sys.argv[1], encoding='utf-8').read()
dec=json.JSONDecoder(); idx=0; records=[]
while idx < len(text):
    while idx < len(text) and text[idx].isspace(): idx += 1
    if idx >= len(text): break
    obj, end = dec.raw_decode(text, idx); records.append(obj); idx = end
assert len(records) == 6, len(records)
for obj in records[:5]:
    assert obj.get('provider_family') == 'data_lake', obj
    assert obj.get('decision') in ('allow','deny'), obj
    assert obj.get('mutated', False) is False, obj
last=records[-1]
assert last['decision'] == 'deny', last
assert last['fail_closed'] is True, last
PYLAKE
echo 'PASS data_lake_provider_fixture_smoke'
