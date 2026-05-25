#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
q = Path('queuebash.sh').read_text()
panel = Path('queuemgr_panel.py').read_text()
cron = Path('bin/bashqueues-cron-ticker.py').read_text()
assert 'QUEUEBASH_VERSION="0.17.25"' in q
assert 'user="${QUEUEBASH_SELECTED_USER:-}"' in q
assert '_queue_root_owner_user 2>/dev/null' in q
assert '_queue_authorise_job()' in q
assert 'SECURITY_AUTHORISATION_CODE' in q
assert '_queue_authorisation_file_status()' in q
assert 'invalid-command-hash' in q
assert 'AUTHORISATION_FILE_INTEGRITY=' in q
assert 'authorise|authorize)' in q
assert '_authorisation_file_command_hash' in cron
assert 'authorise' in panel and 'Authorisation reason' in panel
print('[PASS] job authorisation stamping and validity checks are wired')
PY
