#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
panel="$repo_root/queuemgr_panel.py"
readme="$repo_root/README.md"
qdoc="$repo_root/docs/QUEUEMGR.md"
changelog="$repo_root/CHANGELOG.md"

fail() { echo "[FAIL] $*" >&2; exit 1; }

python3 -m py_compile "$panel" || fail "panel does not compile"

if grep -q 'F11 Exception' "$panel" "$readme" "$qdoc" "$changelog"; then
    fail "F11 is still advertised as the Exception key"
fi

if grep -q 'F11 exception applies' "$panel"; then
    fail "F11 still has old exception status text"
fi

grep -q 'F11 is deliberately not bound' "$panel" || fail "panel does not document unbound F11"
grep -q 'ex / exception' "$panel" || fail "panel missing typed exception fallback note"
grep -q 'clear-exception' "$panel" || fail "panel missing typed clear-exception fallback note"
grep -q 'F11.*not bound' "$readme" || fail "README does not document unbound F11"
grep -q 'F11.*deliberately not used' "$qdoc" || fail "QueueManager docs do not document unbound F11"
grep -q '0.16.17' "$changelog" || fail "CHANGELOG missing 0.16.17"

echo "[PASS] F11 is not used for panel actions on Linux terminals"
