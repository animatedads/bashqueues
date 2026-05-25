#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

python3 - <<'PY'
from pathlib import Path
import re
src = Path('queuebash.sh').read_text()
assert re.search(r'QUEUEBASH_VERSION=\"0\.[0-9]+\.[0-9]+\"', src)
assert '_queue_security_exception_guidance_for_job()' in src
assert 'Security exception guidance' in src
assert '--drop-cap no-network-tools' in src
assert '--drop-cap no-network-sockets' in src
assert '--drop-cap only-local-sockets' in src
assert '--drop-cap no-spawn-shell' in src
assert '--add-port <required-port>' in src
assert '--sandbox-override off' in src
assert '--seccomp-allow @debug' in src
assert 'queue exception add %q %q --reason %q' in src
assert '_queue_security_guidance_probe_preflight_for_current_job' in src
assert '_queue_security_exception_guidance_for_job "$id" "$f" "$log"' in src
print('[PASS] queue explain includes targeted security exception guidance helpers')
PY
