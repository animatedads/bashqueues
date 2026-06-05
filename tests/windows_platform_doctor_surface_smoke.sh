#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT

HOME="$TMP_HOME" QUEUEBASH_ROOT="$TMP_HOME/.queuebash" QUEUEBASH_ALLOW_NONINTERACTIVE=1 bash -lc "cd '$ROOT' && source ./queuebash.sh && queue platform doctor --json" >"$TMP_HOME/platform-doctor.json"
python3 - <<'PY' "$TMP_HOME/platform-doctor.json"
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data=json.load(fh)
assert data['schema']=='queuebash.platform_doctor.v1'
assert data['platform_id'] in {'linux','wsl2','wsl','git-bash','msys2','cygwin','native-windows-powershell','unknown'}
assert data['status'] in {'ok','warning','blocked'}
assert data['policy_ref']=='policies.d/platform/windows-runtime-parity.json'
assert isinstance(data['checks'], list) and data['checks']
assert data['summary']['checks']==len(data['checks'])
if data['platform_id'] in {'git-bash','msys2','cygwin','native-windows-powershell','unknown'}:
    assert data['worker_runtime_supported'] is False
print('PASS windows_platform_doctor_surface_smoke')
PY
