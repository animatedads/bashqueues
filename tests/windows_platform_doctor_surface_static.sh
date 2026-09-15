#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail(){ echo "FAIL $*" >&2; exit 1; }

grep -Fq '_queue_platform_doctor_command()' queuebash.sh || fail 'doctor function missing'
grep -Fq 'queuebash.platform_doctor.v1' queuebash.sh || fail 'doctor JSON schema missing from runtime'
grep -Fq 'doctor|check|test' queuebash.sh || fail 'platform subcommand dispatch missing'
grep -Fq 'queue platform doctor [--json]' docs/WINDOWS_PLATFORM_DOCTOR.md || fail 'doctor doc missing usage'
grep -Fq 'Native PowerShell/Windows Service worker runtime is planned but not supported yet' queuebash.sh || fail 'native Windows fail-closed finding missing'
grep -Fq 'posix_on_windows_no_worker' queuebash.sh || fail 'POSIX-on-Windows fail-closed finding missing'
python3 -m json.tool policies.d/platform/windows-runtime-parity.json >/dev/null || fail 'runtime parity JSON invalid'
python3 - <<'PY'
import json
from pathlib import Path
p=Path('policies.d/platform/windows-runtime-parity.json')
data=json.loads(p.read_text())
surfaces=data.get('surfaces') or []
assert any(x.get('command')=='queue platform doctor [--json]' and x.get('schema')=='queuebash.platform_doctor.v1' and x.get('enables_worker_support') is False for x in surfaces)
PY

echo 'PASS windows platform doctor surface static'
