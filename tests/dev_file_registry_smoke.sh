#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp queuebash.sh "$tmp/queuebash.sh"
cat > "$tmp/sample.sh" <<'SAMPLE'
alpha() {
  echo old
}

beta() {
  echo keep
}
SAMPLE
(
  cd "$tmp"
  export QUEUEBASH_ALLOW_NONINTERACTIVE=1
  export QUEUEBASH_ROOT="$tmp/.queuebash"
  source ./queuebash.sh
  queue dev files begin --file sample.sh --purpose "smoke edit" --function alpha --json >/tmp/qdf_begin.json
  python3 - <<'PY'
from pathlib import Path
p=Path('sample.sh')
s=p.read_text().replace('echo old','echo new')
p.write_text(s)
PY
  queue dev files finish --file sample.sh --function alpha --json >/tmp/qdf_finish.json
  queue dev files changed --json >/tmp/qdf_changed.json
  queue dev patchset create --output "$tmp/patchset.zip" --json >/tmp/qdf_patchset.json
  test -s "$tmp/patchset.zip"
  unzip -l "$tmp/patchset.zip" | grep -q 'manifest.json'
  unzip -l "$tmp/patchset.zip" | grep -q 'files/sample.sh'
  unzip -l "$tmp/patchset.zip" | grep -q 'diffs/sample.sh.diff'
  unzip -l "$tmp/patchset.zip" | grep -q 'scripts/check_preconditions.py'
)
echo "PASS dev_file_registry_smoke"
