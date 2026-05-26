#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
q=Path('queuebash.sh').read_text()
assert '_queue_class_policy_user_grant_values()' in q
assert 'ALLOW_ADD_PORTS' in q
assert 'CLASS_POLICY_USER_${us}_COMMAND_${hs:0:16}_${grant}' in q
p=Path('policies.d/class-statement/default.env').read_text()
assert 'CLASS_POLICY_USER_WEBADMINS_ALLOW_ADD_PORTS' in p
assert 'ALLOW_SANDBOX_OVERRIDES' in p
print('[PASS] class policy per-user standing grants are wired')
PY
