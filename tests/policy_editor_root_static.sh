#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
q = Path('queuebash.sh').read_text()
assert '_queue_policy_edit_target_file()' in q
assert 'root edits the shared' in q
assert 'queue policies edit sandbox|seccomp|class-statement NAME [--shared|--personal]' in q
assert 'queue policies path sandbox|seccomp|class-statement NAME [--shared|--personal]' in q
assert 'SECURITY_SANDBOX_EXPLICIT' in q
assert 'SECURITY_SECCOMP_EXPLICIT' in q
print('[PASS] root-aware policy editor and explicit weak-policy tracking are wired')
PY
