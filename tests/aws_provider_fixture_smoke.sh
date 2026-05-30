#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
export QUEUEBASH_AWS_FIXTURE_DIR="$ROOT/tests/fixtures/aws"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
for cmd in "detect" "metadata" "identity explain" "region explain" "data-protection explain" "itar explain" "finops explain" "resource-shape explain"; do
  providers.d/aws/aws_provider.sh $cmd >>"$tmp"
  printf '\n' >>"$tmp"
done
unset QUEUEBASH_AWS_FIXTURE_DIR
providers.d/aws/aws_provider.sh identity explain >>"$tmp"
python3 - "$tmp" <<'PY'
import json, sys
text=open(sys.argv[1], encoding='utf-8').read()
dec=json.JSONDecoder()
idx=0
records=[]
while idx < len(text):
    while idx < len(text) and text[idx].isspace():
        idx += 1
    if idx >= len(text):
        break
    obj, end = dec.raw_decode(text, idx)
    records.append(obj)
    idx = end
assert len(records)==9, len(records)
for o in records[:8]:
    assert o.get('provider')=='aws'
    assert o.get('decision') in ('allow','deny')
    assert o.get('mutated', False) is False
last=records[-1]
assert last['decision']=='deny'
assert last['fail_closed'] is True
PY
echo '[PASS] aws provider fixture smoke checks pass'
