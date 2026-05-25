#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
q="$repo_root/queuebash.sh"
panel="$repo_root/queuemgr_panel.py"
qdoc="$repo_root/docs/QUEUEMGR.md"
changelog="$repo_root/CHANGELOG.md"

fail() { echo "[FAIL] $*" >&2; exit 1; }
pass() { echo "[PASS] $*"; }

bash -n "$q" || fail "queuebash syntax failed"
python3 -m py_compile "$panel" || fail "panel syntax failed"

grep -q 'QUEUEBASH_VERSION="0.17.25"' "$q" || fail "queuebash version not 0.17.20"
! grep -q '^_queuemgr_print_commands()' "$q" || fail "legacy _queuemgr_print_commands still present"
! grep -q '^_queue_legacy_queuemgr()' "$q" || fail "legacy _queue_legacy_queuemgr still present"
! grep -q '^_queuemgr_repl_complete()' "$q" || fail "legacy _queuemgr_repl_complete still present"
! grep -q 'read -e -r -p "queuemgr> "' "$q" || fail "legacy queuemgr prompt still present"
! grep -q 'bind -x.*_queuemgr_repl_complete' "$q" || fail "legacy completion binding still present"
grep -q 'legacy manager has been removed; use: queue mgr' "$q" || fail "legacy-manager blocker missing"
grep -q '0.16.14 legacy manager cleanup' "$qdoc" || fail "QueueManager docs missing legacy cleanup note"
grep -q '0.16.14' "$changelog" || fail "CHANGELOG missing 0.16.14"

pass "legacy text QueueManager code is physically removed"
pass "panel-only manager entry remains documented"
