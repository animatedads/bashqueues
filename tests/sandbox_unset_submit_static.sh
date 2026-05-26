#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -Eq 'QUEUEBASH_VERSION="0\.[0-9]+\.[0-9]+"' queuebash.sh || fail "queuebash version string missing/malformed"
grep -q 'local sandbox_level="${QUEUEBASH_SANDBOX_LEVEL:-off}"' queuebash.sh || fail "sandbox_level is not initialised with safe default"
grep -q "SANDBOX_LEVEL=%q" queuebash.sh || fail "job record does not persist SANDBOX_LEVEL"

# Make sure the uninitialised variable regression cannot reappear in the submit path.
# Use line numbers, not a broad awk /start/,/end/ pattern range. queuebash.sh is large
# and repeated words such as submit/at/end make pattern ranges flicker.
python3 - <<'PY'
from pathlib import Path
s = Path('queuebash.sh').read_text().splitlines()
start = next((i for i, line in enumerate(s, 1) if line.strip() == 'submit|submit-in|submit-at|in|at)'), None)
if start is None:
    raise SystemExit('[FAIL] submit case arm not found')
local_line = next((i for i in range(start, len(s)+1) if 'local sandbox_level="${QUEUEBASH_SANDBOX_LEVEL:-off}"' in s[i-1]), None)
write_line = next((i for i in range(start, len(s)+1) if "printf 'SANDBOX_LEVEL=%q" in s[i-1]), None)
if local_line is None:
    raise SystemExit('[FAIL] submit path does not declare sandbox_level')
if write_line is None:
    raise SystemExit('[FAIL] submit path does not write SANDBOX_LEVEL')
if local_line > write_line:
    raise SystemExit(f'[FAIL] submit writes SANDBOX_LEVEL at line {write_line} before declaring sandbox_level at line {local_line}')
PY

echo "[PASS] queue submit has a default sandbox level under set -u"
