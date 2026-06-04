#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail(){ echo "[FAIL] $*" >&2; exit 1; }

canonical='/etc/queuebash/policies.d'
legacy='/etc/bashqueues/policies.d'

bash -n install-system.sh || fail 'install-system syntax failed'
bash -n bin/queue-policy-wizard || fail 'policy wizard syntax failed'
python3 -m py_compile bin/queue-remote-management-listener.py || fail 'remote listener py_compile failed'

installer_plan="$(./install-system.sh --dryrun 2>&1 || true)"
printf '%s\n' "$installer_plan" | grep -q "policy dir:    $canonical" || fail 'installer dryrun does not report canonical policy root'
! printf '%s\n' "$installer_plan" | grep -q "$legacy" || fail 'installer dryrun reports legacy policy root'

wizard_json="$(bin/queue-policy-wizard --scope system --dryrun --non-interactive --json)" || fail 'policy wizard system dryrun json failed'
python3 - "$wizard_json" "$canonical" <<'PY' || exit 1
import json, sys
obj=json.loads(sys.argv[1])
canonical=sys.argv[2]
assert obj['schema']=='queuebash.policy_wizard_run.v1'
assert obj['scope']=='system'
assert obj['policy_root']=='/etc/queuebash'
assert all(item['path'].startswith(canonical + '/') for item in obj['files'])
PY

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source queuebash.sh
[[ "$(_queue_policy_shared_root)" == "$canonical" ]] || fail 'runtime shared policy root default is not canonical'

grep -q "$canonical/class-statement/default.env" install-system.sh || fail 'installer root signer path is not canonical'
grep -q "$canonical/code-signing/default.env" install-system.sh || fail 'installer code signing policy path is not canonical'
grep -q "$canonical/remote-queue/remote-management.env" install-system.sh || fail 'installer remote listener verify path is not canonical'
grep -q 'DEFAULT_POLICY_FILE = "/etc/queuebash/policies.d/remote-queue/remote-management.env"' bin/queue-remote-management-listener.py || fail 'remote listener default policy file is not canonical'

grep -q 'Shell function vs installed wrapper' docs/SYSTEM_INSTALL.md || fail 'wrapper behaviour docs missing'
grep -q '/usr/local/bin/queue' docs/SYSTEM_INSTALL.md README.md || fail 'installed wrapper path not documented'

echo '[PASS] policy namespace consistency and wrapper docs are wired'
