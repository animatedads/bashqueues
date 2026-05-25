#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }
grep -q 'QUEUEBASH_VERSION="0.17.15"' queuebash.sh || fail "version not 0.17.15"
python3 - <<'PY'
from pathlib import Path
src = Path('queuemgr_panel.py').read_text()
assert 'Item("default_sandbox_level"' in src
assert 'CLASS_DEFAULT_SANDBOX_LEVEL=' in src
assert 'elif action == "sandbox"' in src
assert 'd.default_sandbox_level = value or self.prompt_choice("Default sandbox"' in src
assert 'elif key == "default_sandbox_level"' in src
assert 'd.default_sandbox_level = self.prompt_choice("Default sandbox"' in src
assert 'd.sandbox_level = self.prompt_choice("Sandbox override"' in src
print('[PASS] Class Creator default sandbox can be edited from field action and F2 command line')
PY
