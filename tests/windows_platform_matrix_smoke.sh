#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="${TMPDIR:-/tmp}/queuebash_windows_matrix_smoke.$$"
rm -rf "$ROOT"
mkdir -p "$ROOT"
printf '0.18.139\n' >"$ROOT/.queuebash_bundled_install_version"
trap 'rm -rf "$ROOT"' EXIT
export QUEUEBASH_ROOT="$ROOT"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh >/dev/null

human="$(queue platform matrix)"
printf '%s\n' "$human" | grep -q 'platform support matrix:'
printf '%s\n' "$human" | grep -q 'wsl2'
printf '%s\n' "$human" | grep -q 'native Windows workers are not supported yet'

json="$(queue platform matrix --json)"
printf '%s\n' "$json" | python3 -m json.tool >/dev/null
json_file="$ROOT/matrix.json"
printf '%s\n' "$json" >"$json_file"
python3 - "$json_file" <<'PY'
import json, sys
data=json.load(open(sys.argv[1], encoding='utf-8'))
assert data['schema'] == 'queuebash.platform_matrix.v1'
by_id={row['platform_id']: row for row in data['tiers']}
assert by_id['wsl2']['worker_runtime_supported'] is True
for name in ['git-bash', 'msys2', 'cygwin', 'native-windows-powershell', 'unknown']:
    assert by_id[name]['runtime_supported'] is False
    assert by_id[name]['worker_runtime_supported'] is False
assert 'native Windows workers are not supported yet' in data['claim']
PY

echo 'PASS windows platform matrix smoke'
