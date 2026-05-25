#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
import re
src = Path('queuebash.sh').read_text()
cap = Path('caps.d/runtime.sh').read_text()
assert re.search(r'QUEUEBASH_VERSION=\"0\.[0-9]+\.[0-9]+\"', src)
assert '_queue_runtime_caps_normalise()' in src
assert 'caps="${caps//_/-}"' in src
assert '_queue_runtime_caps_unknown_list()' in src
assert 'RUNTIME_CAP_WARNING=' in src
assert 'runtime caps norm:' in src
assert 'runtime violation:' in src
assert '_queue_cap_runtime_caps_normalise()' in cap
assert '_queue_cap_runtime_has no-spawn-shell' in cap
print('[PASS] runtime caps normalise underscore spelling and warn on unknown cap names')
PY
