#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
export QUEUEBASH_OBSERVABILITY_BACKEND_FIXTURE_DIR="$ROOT/tests/fixtures/observability_backend"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
for cmd in "detect" "signal explain" "metric explain" "trace explain" "alert explain"; do
  providers.d/observability_backend/observability_backend_provider.sh $cmd >>"$tmp"
  printf '
' >>"$tmp"
done
unset QUEUEBASH_OBSERVABILITY_BACKEND_FIXTURE_DIR
providers.d/observability_backend/observability_backend_provider.sh signal explain >>"$tmp"
python3 - "$tmp" <<'PYOBS'
import json, sys
text=open(sys.argv[1], encoding='utf-8').read()
dec=json.JSONDecoder(); idx=0; records=[]
while idx < len(text):
    while idx < len(text) and text[idx].isspace(): idx += 1
    if idx >= len(text): break
    obj, end = dec.raw_decode(text, idx); records.append(obj); idx = end
assert len(records) == 6, len(records)
for obj in records[:-1]:
    assert obj.get('provider_family') == 'observability_backend', obj
    assert obj.get('decision') in ('allow','deny'), obj
    assert obj.get('mutated', False) is False, obj
last=records[-1]
assert last['decision'] == 'deny', last
assert last['fail_closed'] is True, last
PYOBS
echo 'PASS observability_backend_provider_fixture_smoke'
