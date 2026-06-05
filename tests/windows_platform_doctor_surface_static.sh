#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
fail(){ echo "FAIL windows_platform_doctor_surface_static: $*" >&2; exit 1; }

cd "$ROOT"
grep -Fq '0.18.125 BOB30 Windows platform doctor surface' README.md || fail 'README top entry missing'
grep -Fq '0.18.125 BOB30 Windows platform doctor surface' CHANGELOG.md || fail 'CHANGELOG top entry missing'
grep -Fq '_queue_platform_doctor_command()' queuebash.sh || fail 'doctor function missing'
grep -Fq 'queuebash.platform_doctor.v1' queuebash.sh || fail 'doctor JSON schema missing'
grep -Fq 'queue platform doctor [--json]' docs/WINDOWS_RUNTIME_PLAN.md || fail 'runtime plan missing doctor command'
grep -Fq 'queue platform doctor --json' docs/WINDOWS_WSL2_QUICKSTART.md || fail 'quickstart missing doctor command'
grep -Fq '"plan","platform","plugins"' queuebash.sh || fail 'command catalog missing platform'
python3 -m json.tool policies.d/platform/windows-runtime-parity.json >/dev/null || fail 'windows runtime parity JSON invalid'
python3 - <<'PY'
import json, pathlib
root=pathlib.Path.cwd()
data=json.loads((root/'policies.d/platform/windows-runtime-parity.json').read_text())
doctor=data['platform_doctor_surface']
assert doctor['command']=='queue platform doctor [--json]'
assert doctor['schema']=='queuebash.platform_doctor.v1'
assert 'workers' in doctor['must_not_mutate']
assert 'git-bash' in doctor['blocks_worker_claim_for']
print('PASS windows_platform_doctor_policy_json')
PY
echo 'PASS windows_platform_doctor_surface_static'
