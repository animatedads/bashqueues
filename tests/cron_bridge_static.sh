#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
q=Path('queuebash.sh').read_text()
assert 'QUEUEBASH_VERSION="0.17.19"' in q
assert '_queue_cron_command()' in q
assert 'cron|crontab|cron-bridge)' in q
assert Path('bin/bashqueues-cron-ticker.py').exists()
assert Path('bin/bashqueues-crontab').exists()
assert Path('systemd/bashqueues-cron.timer').exists()
assert Path('systemd/bashqueues-cron.service').exists()
t=Path('bin/bashqueues-cron-ticker.py').read_text()
assert 'CLASS_MAX_CONCURRENT=1' in t
assert 'runuser' in t
assert 'already_dispatched' in t
assert 'should_run' in t
assert '/usr/bin/crontab' not in t
shim=Path('bin/bashqueues-crontab').read_text()
assert 'SPOOL_DIR="${QUEUEBASH_CRON_SPOOL_DIR:-/var/spool/bashqueues_cron}"' in shim
assert Path('docs/CRON_BRIDGE.md').exists()
print('[PASS] cron bridge is installed as queue-first optional scheduler')
PY
