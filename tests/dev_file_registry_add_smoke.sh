#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp queuebash.sh "$tmp/queuebash.sh"
cat > "$tmp/newfile.txt" <<'SAMPLE'
hello from a newly added file
SAMPLE
(
  cd "$tmp"
  export QUEUEBASH_ALLOW_NONINTERACTIVE=1
  export QUEUEBASH_ROOT="$tmp/.queuebash"
  source ./queuebash.sh
  queue dev files add --file newfile.txt --purpose "new file smoke" --json >/tmp/qdf_add.json
  queue dev files changed --json >/tmp/qdf_add_changed.json
  python3 - <<'PY'
import json
add=json.load(open('/tmp/qdf_add.json'))
assert add['status']=='added'
d=json.load(open('/tmp/qdf_add_changed.json'))
entries=[e for e in d['entries'] if e['relpath']=='newfile.txt']
assert entries, d
assert entries[0]['changed'] is True
assert entries[0]['baseline']['md5'] is None
assert entries[0]['current']['md5']
PY
)
echo "PASS dev_file_registry_add_smoke"
