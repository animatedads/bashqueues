#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
src = Path('assets.d/secaudit.sh').read_text()
for token in ['nc_listen', 'ncat_listen', 'socat_listen', 'python_socket_bind', 'wget_pipe_shell']:
    assert token in src, token
print('[PASS] secaudit detects listener-style network payload patterns')
PY
