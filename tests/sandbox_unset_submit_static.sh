#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -q 'QUEUEBASH_VERSION="0.17.15"' queuebash.sh || fail "version not 0.17.15"
grep -q 'local sandbox_level="${QUEUEBASH_SANDBOX_LEVEL:-off}"' queuebash.sh || fail "sandbox_level is not initialised with safe default"
grep -q "SANDBOX_LEVEL=%q" queuebash.sh || fail "job record does not persist SANDBOX_LEVEL"

# Make sure the uninitialised variable regression cannot reappear in the submit path.
if awk '/submit\|submit-in\|submit-at\|in\|at\)/,/printf .SANDBOX_LEVEL=/' queuebash.sh | grep -q 'local sandbox_level'; then
  :
else
  fail "submit path writes SANDBOX_LEVEL before declaring sandbox_level"
fi

echo "[PASS] queue submit has a default sandbox level under set -u"
