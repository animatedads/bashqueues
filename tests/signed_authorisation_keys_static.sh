#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
import re
q = Path('queuebash.sh').read_text()
pol = Path('policies.d/class-statement/default.env').read_text()
doc = Path('docs/CLASS_POLICY_STATEMENT.md').read_text()
assert re.search(r'QUEUEBASH_VERSION=\"0\.[0-9]+\.[0-9]+\"', q)
assert '_queue_authorisation_keygen()' in q
assert 'openssl genpkey -algorithm ED25519' in q
assert 'queue keygen authorisation' in q
assert 'queue keys list' in q or 'keys)' in q
assert 'AUTHORISATION_SIGNATURE_B64' in q
assert '_queue_authorisation_verify_signature_loaded()' in q
assert 'CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED' in pol
assert 'CLASS_POLICY_AUTHORISATION_SIGNER_ROOT_PUBLIC_KEY_PEM_B64' in pol
assert 'valid-signed' in q
assert 'Signed authorisation keys' in doc
print('[PASS] signed authorisation key generation and policy trust hooks are present')
PY
