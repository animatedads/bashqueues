#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT

HOME="$TMP_HOME" QUEUEBASH_ROOT="$TMP_HOME/.queuebash" QUEUEBASH_ALLOW_NONINTERACTIVE=1 bash -lc "cd '$ROOT' && source ./queuebash.sh && queue platform --json" >"$TMP_HOME/platform.json"
python3 - <<'PY' "$TMP_HOME/platform.json"
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data=json.load(fh)
assert data['schema']=='queuebash.platform_facts.v1'
assert data['platform_id'] in {'linux','wsl2','wsl','git-bash','msys2','cygwin','native-windows-powershell','unknown'}
assert 'support_tier' in data
assert 'worker_runtime_supported' in data
assert data['policy_ref']=='policies.d/platform/windows-runtime-parity.json'
if data['platform_id'] in {'git-bash','msys2','cygwin','native-windows-powershell','unknown'}:
    assert data['worker_runtime_supported'] is False
print('PASS windows_platform_fact_surface_smoke')
PY
