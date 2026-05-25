#!/usr/bin/env bash
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$src"

grep -q 'QUEUEBASH_VERSION="0.17.25"' queuebash.sh

for f in \
  policies.d/sandbox/off.env \
  policies.d/sandbox/network-none.env \
  policies.d/sandbox/restrict-egress.env \
  policies.d/sandbox/strict.env \
  policies.d/seccomp/off.env \
  policies.d/seccomp/docker-default.env \
  policies.d/seccomp/strict.env; do
  test -f "$f"
done

grep -q '_queue_install_bundled_policies' queuebash.sh
grep -q '_queue_policy_file' queuebash.sh
grep -q '_queue_policy_list' queuebash.sh
grep -q 'queue policies list' queuebash.sh
grep -q 'SANDBOX_SYSTEMD_PROPERTIES' policies.d/sandbox/strict.env
grep -q 'SECCOMP_SYSTEMD_PROPERTIES' policies.d/seccomp/docker-default.env

# The hard-coded systemd property strings should live in policy files, not in
# the emit functions. This guards the design direction without banning docs/tests.
python3 - <<'PY'
from pathlib import Path
src = Path('queuebash.sh').read_text()
start = src.index('_queue_emit_sandbox_systemd_props()')
end = src.index('_queue_runtime_caps_drop_list()')
block = src[start:end]
assert 'PrivateNetwork=yes' not in block
assert 'IPAddressAllow=10.0.0.0/8' not in block
assert 'SystemCallFilter=~@clock' not in block
print('[PASS] security launch profiles are loaded from policy files')
PY

grep -q 'def sandbox_policy_choices' queuemgr_panel.py
grep -q 'qrun(\["policies", "list", "sandbox"\]' queuemgr_panel.py
