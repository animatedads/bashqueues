#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp queuebash.sh "$tmp/queuebash.sh"
cat > "$tmp/sample.sh" <<'SAMPLE'
alpha() {
  echo old-alpha
}

beta() {
  echo old-beta
}
SAMPLE
(
  cd "$tmp"
  export QUEUEBASH_ALLOW_NONINTERACTIVE=1
  export QUEUEBASH_ROOT="$tmp/.queuebash"
  source ./queuebash.sh
  queue dev files begin --file sample.sh --purpose "scoped edit" --function alpha --json >/tmp/qdf_scope_begin.json
  python3 - <<'PY'
from pathlib import Path
p=Path('sample.sh')
s=p.read_text().replace('old-alpha','new-alpha').replace('old-beta','new-beta')
p.write_text(s)
PY
  queue dev files finish --file sample.sh --function alpha --json >/tmp/qdf_scope_finish.json
  queue dev files changed --json >/tmp/qdf_scope_changed.json
  python3 - <<'PY'
import json
for path in ['/tmp/qdf_scope_finish.json','/tmp/qdf_scope_changed.json']:
    d=json.load(open(path))
    entries=d.get('entries') or [d]
    for e in entries:
        funcs=[x['function'] for x in e.get('changed_functions',[])]
        assert funcs == ['alpha'], (path, funcs)
PY
)
echo "PASS dev_file_registry_scoped_functions_smoke"
