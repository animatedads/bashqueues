#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
src = Path('bin/bashqueues-cron-ticker.py').read_text()
q = Path('queuebash.sh').read_text()
assert 'def stable_name(user: str, command: str)' in src
assert 'f"{user}\\0{command}"' in src
assert 'CRON_MACROS' in src and '@hourly' in src and '@reboot' in src
assert 'cleanup_state_markers' in src
assert 'QUEUEBASH_CRON_STATE_MAX_AGE_DAYS' in src
assert 'class_body=' in src and 'if [[ ! -f' in src
assert 'preview)' in q and '--dryrun' in q
assert 'show|cat)' in q
assert 'grep -v' in q and '=== user bashqueues crontabs ===' in q
PY

echo "[PASS] cron bridge review fixes are present"
