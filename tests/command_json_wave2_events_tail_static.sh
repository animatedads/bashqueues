#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

python3 - <<'PY'
from pathlib import Path
s = Path('queuebash.sh').read_text()
checks = {
    'version marker': 'QUEUEBASH_VERSION="',
    'events schema': 'queuebash.events.v1',
    'events json flag': '--json|-j) json=1',
    'events follow flag': '--follow|-f|follow) follow=1',
    'bounded tail help': 'queue events --tail N exits after printing N events.',
    'explicit follow help': 'queue events --follow follows the event log.',
    'tail without follow': 'tail -n "$n" "$events_path"',
    'tail with follow': 'tail -n "$n" -f "$events_path"',
}
missing = [name for name, needle in checks.items() if needle not in s]
if missing:
    raise SystemExit('missing static checks: ' + ', '.join(missing))
PY

echo '[PASS] command JSON wave2 events tail/follow static checks pass'
