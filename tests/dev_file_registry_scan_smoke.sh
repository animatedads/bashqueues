#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp queuebash.sh "$tmp/queuebash.sh"
cat > "$tmp/sample.sh" <<'SAMPLE'
alpha() {
  echo one
}
SAMPLE
(
  cd "$tmp"
  export QUEUEBASH_ALLOW_NONINTERACTIVE=1
  export QUEUEBASH_ROOT="$tmp/.queuebash"
  source ./queuebash.sh
  queue dev files begin --file sample.sh --purpose "scan baseline" --json >/tmp/qdfs_begin.json
  sed -i 's/one/two/' sample.sh
  queue dev files scan --json >/tmp/qdfs_scan.json
  python3 - <<'PY'
import json
scan=json.load(open('/tmp/qdfs_scan.json'))
assert scan['schema']=='queuebash.dev_file_registry.v1'
assert scan['scanned'] >= 1
assert scan['changed'] >= 1
entries=scan['entries']
entry=[e for e in entries if e.get('relpath')=='sample.sh'][0]
assert entry.get('changed') is True
assert entry.get('current',{}).get('md5')
assert entry.get('baseline',{}).get('md5') != entry.get('current',{}).get('md5')
PY
)
echo "PASS dev_file_registry_scan_smoke"
