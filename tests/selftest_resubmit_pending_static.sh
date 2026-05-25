#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "[FAIL] $*" >&2; exit 1; }
cd "$(dirname "$0")/.."

grep -q 'queue run --workers 3' tests/selftest.sh || fail "selftest must run enough workers to execute failer before resubmit"
grep -q 'expected failer to be failed before resubmit' tests/selftest.sh || fail "selftest must assert failer terminal state before resubmit"
grep -q 'queue resubmit failer' tests/selftest.sh || fail "selftest still needs to exercise resubmit"

echo "[PASS] selftest resubmit smoke waits for failer to fail before resubmit"
