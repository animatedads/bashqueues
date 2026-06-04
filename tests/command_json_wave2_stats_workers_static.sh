#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

python3 - <<'PY'
from pathlib import Path
text = Path('queuebash.sh').read_text()
checks = {
    'stats schema': '"schema":"queuebash.stats.v1"',
    'stats json flag': '--json|-j) json=1; shift ;;',
    'workers schema': '"schema":"queuebash.workers.v1"',
    'workers count': '],"count":%d}',
}
missing = [name for name, needle in checks.items() if needle not in text]
if missing:
    raise SystemExit('missing command JSON wave2 markers: ' + ', '.join(missing))
PY
