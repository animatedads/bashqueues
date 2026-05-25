#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
q="$repo_root/queuebash.sh"
changelog="$repo_root/CHANGELOG.md"

fail() { echo "[FAIL] $*" >&2; exit 1; }
pass() { echo "[PASS] $*"; }

grep -q 'QUEUEBASH_VERSION="0.17.51"' "$q" || fail "queuebash version not 0.17.20"
grep -q 'Usage: queue ${1:---queue-user} USER \[command\] \[args\.\.\.\]' "$q" || fail "--queue-user usage does not allow selection-only form"
grep -q 'Usage: queue user USER \[command\] \[args\.\.\.\]' "$q" || fail "queue user usage does not allow selection-only form"
grep -q 'if \[\[ "$#" -eq 0 \]\]; then' "$q" || fail "selector does not stop after selection-only form"
grep -q '_queue_print_selected_user_banner' "$q" || fail "selected queue user banner helper missing"
grep -q 'QUEUE USER:' "$q" || fail "selected queue user banner text missing"
grep -q '_queue_print_selected_user_banner' "$q" || fail "job table does not print selected user context"
grep -q '0.16.13' "$changelog" || fail "CHANGELOG missing 0.16.13"

pass "queue-user selection-only form and visible selected context are present"
