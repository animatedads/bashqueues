#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
s=Path('queuebash.sh').read_text()
assert 'QUEUEBASH_VERSION="0.17.51"' in s
assert '_queue_authorisation_publish_file_permissions' in s
assert 'chmod 0444 "$file"' in s
assert '_queue_authorisation_policy_has_any_public_keys' in s
assert 'invalid-untrusted-admin' in s
assert 'invalid-missing-signature' in s
PY
echo '[PASS] authorisation readable-file and signature-policy enforcement hooks are present'
