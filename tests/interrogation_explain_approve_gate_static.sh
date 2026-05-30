#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }
grep -Eq 'QUEUEBASH_VERSION="0\.[0-9]+\.[0-9]+"' queuebash.sh || fail "queuebash version string missing/malformed"
grep -q 'explain|review' queuebash.sh || fail "profile explain/review route missing"
grep -q 'approval_requires_accept_risk' bin/queue-interrogate-compile || fail "risk approval gate missing"
grep -q 'SIGNED_BY' bin/queue-interrogate-compile || fail "signed_by stamp missing"
grep -q -- '--accept-warnings' bin/queue-interrogate-compile || fail "accept warnings option missing"
grep -q -- '--accept-risk' bin/queue-interrogate-compile || fail "accept risk option missing"
echo '[PASS] interrogation explain/approve gate static checks pass'
