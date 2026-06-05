#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
fail(){ echo "FAIL windows_platform_fact_surface_static: $*" >&2; exit 1; }

cd "$ROOT"
grep -Fq '0.18.124 BOB30 Windows platform fact surface' README.md || fail 'README top entry missing'
grep -Fq '0.18.124 BOB30 Windows platform fact surface' CHANGELOG.md || fail 'CHANGELOG top entry missing'
grep -Fq '_queue_platform_detect_id()' queuebash.sh || fail 'platform detection function missing'
grep -Fq '_queue_platform_command()' queuebash.sh || fail 'platform command function missing'
grep -Fq 'platform|platforms|runtime-platform)' queuebash.sh || fail 'dispatcher route missing'
grep -Fq 'queuebash.platform_facts.v1' queuebash.sh || fail 'platform JSON schema missing in command'
grep -Fq 'queue platform [--json]' docs/WINDOWS_RUNTIME_PLAN.md || fail 'runtime plan missing platform command'
grep -Fq 'queue platform --json' docs/WINDOWS_WSL2_QUICKSTART.md || fail 'quickstart missing platform command'
python3 -m json.tool policies.d/platform/windows-runtime-parity.json >/dev/null || fail 'windows runtime parity JSON invalid'
python3 - <<'PY'
import json, pathlib
root=pathlib.Path.cwd()
data=json.loads((root/'policies.d/platform/windows-runtime-parity.json').read_text())
surf=data['platform_fact_surface']
assert surf['command']=='queue platform [--json]'
assert surf['schema']=='queuebash.platform_facts.v1'
assert 'native-windows-powershell' in surf['must_not_enable_worker_runtime_for']
print('PASS windows_platform_fact_surface_policy_json')
PY
echo 'PASS windows_platform_fact_surface_static'
