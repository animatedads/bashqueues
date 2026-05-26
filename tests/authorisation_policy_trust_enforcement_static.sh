#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
q = Path('queuebash.sh').read_text()
assert 'queue authorisation generate: policy requires a valid signature for admin' in q
assert 'queue authorise: policy requires a valid signature for admin' in q
assert '_queue_authorisation_signature_admin_requirement' in q
assert '_queue_authorisation_policy_show' in q
assert 'queue authorisation policy' in q or 'policy|trust|trusted' in q
print('[PASS] authorisation generation refuses unsigned records required by policy trust list')
PY
