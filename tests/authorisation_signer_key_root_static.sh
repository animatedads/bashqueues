#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
q = Path('queuebash.sh').read_text()
assert '_queue_authorisation_signer_key_root()' in q
assert 'Signing keys belong to the signer/admin identity' in q
assert '_queue_authorisation_signer_private_key_file "$admin" "$key_name"' in q
assert 'QUEUEBASH_AUTHORISATION_KEY_ROOT' in q
assert 'signing_key_root:' in q
print('[PASS] authorisation signer key root is separated from selected queue root')
PY
