#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
fail(){ echo "[FAIL] $1" >&2; exit 1; }
pass(){ echo "[PASS] $1"; }
python3 -m py_compile "$repo_root/queuemgr5250.py" || fail "queuemgr5250.py does not compile"
bash -n "$repo_root/queuemgr.sh" || fail "queuemgr.sh syntax failed"
bash -n "$repo_root/queuebash.sh" || fail "queuebash.sh syntax failed"
grep -q 'queue mgr 5250' "$repo_root/README.md" || fail "README missing 5250 manager docs"
grep -q 'Restriction Builder' "$repo_root/queuemgr5250.py" || fail "manager missing restriction builder panel"
grep -q 'exception add' "$repo_root/queuemgr5250.py" || fail "manager missing exception workflow"
grep -q 'QUEUEBASH_COMMAND_ARG_1_ABSPATH' "$repo_root/queuemgr5250.py" || fail "manager missing selectable variables"
pass "5250 manager compiles"
pass "5250 manager is documented"
pass "5250 manager includes panels, exceptions, and restriction variables"
echo
echo "bashqueues 5250 manager static tests: OK"
