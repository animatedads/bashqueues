#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp queuebash.sh "$tmp/queuebash.sh"
cat > "$tmp/new_helper.sh" <<'SAMPLE'
new_helper() {
  echo new
}
SAMPLE
(
  cd "$tmp"
  export QUEUEBASH_ALLOW_NONINTERACTIVE=1
  export QUEUEBASH_ROOT="$tmp/.queuebash"
  source ./queuebash.sh
  queue dev files add --file new_helper.sh --purpose "new helper" --function new_helper --json >/tmp/qdpa_add.json
  queue dev files scan --json >/tmp/qdpa_scan.json
  queue dev files changed --json >/tmp/qdpa_changed.json
  queue dev patchset create --output "$tmp/newfile.patchset.zip" --json >/tmp/qdpa_patchset.json
  unzip -l "$tmp/newfile.patchset.zip" | grep -q 'files/new_helper.sh'
  unzip -p "$tmp/newfile.patchset.zip" manifest.json >/tmp/qdpa_manifest.json
  python3 - <<'PY'
import json
m=json.load(open('/tmp/qdpa_manifest.json'))
entry=[e for e in m['entries'] if e['relpath']=='new_helper.sh'][0]
assert entry['file_old_md5'] is None
assert entry['file_new_md5']
assert entry['baseline_present'] is False
PY
  mkdir target
  unzip -q "$tmp/newfile.patchset.zip" -d patchset
  patchset/review_diff.sh target >/tmp/qdpa_review.txt
  grep -q 'ready_new_file_absent' /tmp/qdpa_review.txt
  patchset/apply_patchset.sh target >/tmp/qdpa_apply.txt
  test -f target/new_helper.sh
)
echo "PASS dev_patchset_new_file_smoke"
