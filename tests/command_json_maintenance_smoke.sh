#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
trap 'rm -rf "$QUEUEBASH_ROOT" "$tmpout"' EXIT
tmpout="$(mktemp -d)"
source ./queuebash.sh >/dev/null
queue submit maintjson -- bash -c 'echo maint-json' >/dev/null
queue run --workers 1 >/dev/null
python3 - <<'PY' "$QUEUEBASH_ROOT"
import pathlib, sys
root=pathlib.Path(sys.argv[1])
job=next((root/'done').glob('*.job'))
qid=job.stem
(root/'logs'/f'{qid}.log').write_text('hello log\n')
print(qid)
PY
queue clean-logs --json > "$tmpout/clean.json"
python3 - <<'PY' "$tmpout/clean.json"
import json, sys
j=json.load(open(sys.argv[1])); assert j['schema']=='queuebash.command_result.v1'; assert j['command']=='clean-logs'; assert j['dryrun'] is True; assert 'matched' in j
PY
queue compress-logs --json > "$tmpout/compress.json"
python3 - <<'PY' "$tmpout/compress.json"
import json, sys
j=json.load(open(sys.argv[1])); assert j['schema']=='queuebash.command_result.v1'; assert j['command']=='compress-logs'; assert 'matched' in j and 'changed' in j
PY
queue backup --json --output "$tmpout/backup.tar.gz" > "$tmpout/backup.json"
python3 - <<'PY' "$tmpout/backup.json" "$tmpout/backup.tar.gz"
import json, sys, pathlib
j=json.load(open(sys.argv[1])); assert j['schema']=='queuebash.command_result.v1'; assert j['command']=='backup'; assert j['ok'] is True; assert pathlib.Path(sys.argv[2]).exists()
PY
queue backup restore "$tmpout/backup.tar.gz" --to "$tmpout/restored" --json > "$tmpout/restore.json"
python3 - <<'PY' "$tmpout/restore.json" "$tmpout/restored"
import json, sys, pathlib
j=json.load(open(sys.argv[1])); assert j['schema']=='queuebash.command_result.v1'; assert j['command']=='backup restore'; assert j['ok'] is True; assert pathlib.Path(sys.argv[2]).exists()
PY
if queue reevaluate --json > "$tmpout/reeval.json" 2>/dev/null; then
  false
else
  python3 - <<'PY' "$tmpout/reeval.json"
import json, sys
j=json.load(open(sys.argv[1])); assert j['schema']=='queuebash.command_result.v1'; assert j['ok'] is False; assert j['error']['code']=='no_match'
PY
fi
echo PASS command_json_maintenance_smoke
