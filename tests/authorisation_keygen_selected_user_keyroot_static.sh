#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
q = Path('queuebash.sh').read_text()
assert 'Root using `queue --queue-user hc3 ...` must manage' in q
assert 'selected_user="${QUEUEBASH_SELECTED_USER:-}"' in q
assert 'selected_user" != "$actor"' in q
assert 'Preserve ordinary single-user/test behaviour' in q
assert 'Root authorising hc3' in q
print('[PASS] selected-user keygen/signing key-root separation is wired')
PY
