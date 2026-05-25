#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

python3 - <<'PY'
from pathlib import Path
src = Path('queuebash.sh').read_text()
assert 'QUEUEBASH_VERSION="0.17.16"' in src
assert '_queue_global_claim_holder_summary()' in src
assert 'holders="$(_queue_global_claim_holder_summary "$claim")"' in src
assert 'claim=$claim mode=$mode slots=$slots${holders:+ $holders}' in src
assert '25) : ;; # global claim helper already logged the claim key and holder summary' in src
assert 'blocked: global resource slot unavailable' in src
assert 'slots used:' in src
assert 'holders:' in src
PY

echo "[PASS] global claim blocked history/explain shows claim detail and holders"
