#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
export QUEUEBASH_CONTAINER_REGISTRY_FIXTURE_DIR="$ROOT/tests/fixtures/container_registry"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
for cmd in "detect" "image explain" "provenance explain" "vulnerability explain" "retention explain"; do
  providers.d/container_registry/container_registry_provider.sh $cmd >>"$tmp"
  printf '\n' >>"$tmp"
done
unset QUEUEBASH_CONTAINER_REGISTRY_FIXTURE_DIR
providers.d/container_registry/container_registry_provider.sh image explain >>"$tmp"
python3 - "$tmp" <<'PY'
import json, sys
text=open(sys.argv[1], encoding='utf-8').read()
dec=json.JSONDecoder(); idx=0; records=[]
while idx < len(text):
    while idx < len(text) and text[idx].isspace(): idx += 1
    if idx >= len(text): break
    obj, end = dec.raw_decode(text, idx); records.append(obj); idx = end
assert len(records) == 6, len(records)
for obj in records[:5]:
    assert obj.get('provider_family') == 'container_registry', obj
    assert obj.get('decision') in ('allow','deny'), obj
    assert obj.get('mutated', False) is False, obj
last=records[-1]
assert last['decision'] == 'deny', last
assert last['fail_closed'] is True, last
PY
echo 'PASS container_registry_provider_fixture_smoke'
