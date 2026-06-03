#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
export QUEUEBASH_VECTOR_DATABASE_FIXTURE_DIR="$ROOT/tests/fixtures/vector_database"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
for cmd in "detect" "collection explain" "index explain" "embedding-policy explain" "retention explain"; do
  providers.d/vector_database/vector_database_provider.sh $cmd >>"$tmp"
  printf '
' >>"$tmp"
done
unset QUEUEBASH_VECTOR_DATABASE_FIXTURE_DIR
providers.d/vector_database/vector_database_provider.sh collection explain >>"$tmp"
python3 - "$tmp" <<'PYVEC'
import json, sys
text=open(sys.argv[1], encoding='utf-8').read()
dec=json.JSONDecoder(); idx=0; records=[]
while idx < len(text):
    while idx < len(text) and text[idx].isspace(): idx += 1
    if idx >= len(text): break
    obj, end = dec.raw_decode(text, idx); records.append(obj); idx = end
assert len(records) == 6, len(records)
for obj in records[:5]:
    assert obj.get('provider_family') == 'vector_database', obj
    assert obj.get('decision') in ('allow','deny'), obj
    assert obj.get('mutated', False) is False, obj
last=records[-1]
assert last['decision'] == 'deny', last
assert last['fail_closed'] is True, last
PYVEC
echo 'PASS vector_database_provider_fixture_smoke'
