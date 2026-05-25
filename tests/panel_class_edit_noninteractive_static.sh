#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
src = Path('queuemgr_panel.py').read_text()
assert 'def _coerce_subprocess_text' in src
assert '_coerce_subprocess_text(exc.stdout)' in src
assert 'def load_class_into_creator' in src
assert 'qrun(["classes", "show", class_name]' in src
assert 'qrun(["classes", "edit"' not in src
assert 'qrun(["classes", "edit", it.key]' not in src
assert 'Loaded class {class_name} into Class Creator' in src
print('[PASS] Queue Manager class edit is noninteractive and qrun timeout output is text-safe')
PY
