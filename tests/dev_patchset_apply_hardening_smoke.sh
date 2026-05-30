#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
SRC="$WORK/src"
DST="$WORK/dst"
mkdir -p "$SRC/.queuebash/dev" "$DST/.queuebash/dev"
cp "$ROOT/queuebash.sh" "$SRC/queuebash.sh"
cp "$ROOT/queuebash.sh" "$DST/queuebash.sh"
cat > "$SRC/.queuebash/dev/scratchpad.json" <<'JSON'
{
  "items": [
    {"id":"base-item","kind":"decision","text":"base"}
  ]
}
JSON
cp "$SRC/.queuebash/dev/scratchpad.json" "$DST/.queuebash/dev/scratchpad.json"
cat > "$SRC/demo.txt" <<'EOF2'
old
EOF2
cp "$SRC/demo.txt" "$DST/demo.txt"
cd "$SRC"
QUEUEBASH_ALLOW_NONINTERACTIVE=1 QUEUEBASH_ROOT="$SRC/.queuebash" bash -lc 'source ./queuebash.sh; queue dev files begin --file demo.txt --purpose demo --json' >/dev/null
printf 'new\n' > demo.txt
QUEUEBASH_ALLOW_NONINTERACTIVE=1 QUEUEBASH_ROOT="$SRC/.queuebash" bash -lc 'source ./queuebash.sh; queue dev files finish --file demo.txt --json' >/dev/null
QUEUEBASH_ALLOW_NONINTERACTIVE=1 QUEUEBASH_ROOT="$SRC/.queuebash" bash -lc 'source ./queuebash.sh; queue dev files add --file .queuebash/dev/scratchpad.json --purpose scratchpad --json' >/dev/null
python3 - <<'PY'
import json, pathlib
p=pathlib.Path('.queuebash/dev/scratchpad.json')
d=json.loads(p.read_text())
d['items'].append({'id':'patch-item','kind':'task','text':'from patch'})
p.write_text(json.dumps(d,indent=2,sort_keys=True)+'\n')
PY
QUEUEBASH_ALLOW_NONINTERACTIVE=1 QUEUEBASH_ROOT="$SRC/.queuebash" bash -lc 'source ./queuebash.sh; queue dev files finish --file .queuebash/dev/scratchpad.json --json' >/dev/null
QUEUEBASH_ALLOW_NONINTERACTIVE=1 QUEUEBASH_ROOT="$SRC/.queuebash" bash -lc 'source ./queuebash.sh; queue dev patchset create --output "$0" --json' "$WORK/ps.zip" >/dev/null
unzip -q "$WORK/ps.zip" -d "$WORK/ps"
"$WORK/ps/apply_patchset.sh" --help >/dev/null
"$WORK/ps/apply_patchset.sh" --check "$DST" >/dev/null
"$WORK/ps/apply_patchset.sh" --backup-dir "$WORK/backups" "$DST" >/tmp/apply.out
[ -f "$DST/.queuebash/dev/scratchpad.json" ]
python3 - "$DST/.queuebash/dev/scratchpad.json" <<'PY'
import json, pathlib, sys
p=pathlib.Path(sys.argv[1]); d=json.loads(p.read_text()); ids={i.get('id') for i in d.get('items',[])}
assert 'base-item' in ids and 'patch-item' in ids, ids
assert d.get('merge_history'), d
PY
find "$WORK/backups" -name backup_manifest.json -print -quit | grep -q backup_manifest.json

echo "PASS dev_patchset_apply_hardening_smoke"
