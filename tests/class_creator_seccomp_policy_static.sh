#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
src = Path('queuemgr_panel.py').read_text()
assert 'def seccomp_policy_choices(self)' in src
assert 'qrun(["policies", "list", "seccomp"]' in src
assert 'docker-default' in src
assert 'Item("default_seccomp_profile"' in src
assert 'Item("default_seccomp_allow"' in src
assert 'action == "seccomp"' in src
assert 'action == "seccomp-allow"' in src
assert 'key == "default_seccomp_profile"' in src
assert 'key == "default_seccomp_allow"' in src
assert 'CLASS_DEFAULT_SECCOMP_PROFILE=' in src
assert 'CLASS_DEFAULT_SECCOMP_ALLOW=' in src
print('[PASS] Class Creator exposes seccomp policy and allow-list fields')
PY
