#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

python3 - <<'PY'
from pathlib import Path
src = Path('queuebash.sh').read_text()
assert 'QUEUEBASH_VERSION="0.17.51"' in src
assert 'CLASS_DEFAULT_SANDBOX_LEVEL' in src
assert '--sandbox' in src
assert '_queue_emit_sandbox_systemd_props' in src
assert 'PrivateNetwork=yes' in Path('policies.d/sandbox/strict.env').read_text()
assert 'IPAddressDeny=any' in Path('policies.d/sandbox/restrict-egress.env').read_text()
assert 'ProtectSystem=strict' in Path('policies.d/sandbox/strict.env').read_text()
assert 'NoNewPrivileges=yes' in Path('policies.d/sandbox/strict.env').read_text()
assert '_queue_emit_sandbox_direct_prefix' in src
assert 'SANDBOX_DIRECT_PREFIX=(unshare --net -r --)' in Path('policies.d/sandbox/strict.env').read_text()
assert 'SANDBOX_LEVEL=%q' in src
PY

echo '[PASS] runtime sandbox flags/class defaults are wired into launcher'
