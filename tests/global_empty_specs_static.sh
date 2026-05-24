#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "[FAIL] $*" >&2; exit 1; }
cd "$(dirname "$0")/.."

if grep -q 'QUEUE_CLASS_GLOBAL_CLAIM_SPECS\[@\]:-' queuebash.sh; then
    fail "empty global claim arrays must not expand to one empty spec"
fi
grep -q 'for spec in "${QUEUE_CLASS_GLOBAL_CLAIM_SPECS\[@\]}"; do' queuebash.sh || fail "global claim loops must iterate real specs only"

echo "[PASS] empty global claim lists do not block ordinary jobs"
