#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
fail(){ echo "[FAIL] $1" >&2; exit 1; }
pass(){ echo "[PASS] $1"; }

bash -n "$repo_root/queuebash.sh" || fail "queuebash syntax"

grep -q '_queue_exception_explain_for_job()' "$repo_root/queuebash.sh" || fail "exception explain renderer missing"
grep -q 'echo "Exception overlays"' "$repo_root/queuebash.sh" || fail "exception section heading missing"
grep -q 'echo "  none"' "$repo_root/queuebash.sh" || fail "exception none output missing"
grep -q 'reason:' "$repo_root/queuebash.sh" || fail "exception reason output missing"
grep -q 'created:' "$repo_root/queuebash.sh" || fail "exception created output missing"
grep -q '_queue_exception_explain_for_job "$id"' "$repo_root/queuebash.sh" || fail "queue explain does not call exception renderer"
grep -q 'Exception overlays in explain' "$repo_root/README.md" || fail "README missing explain docs"

pass "queue explain has exception overlay renderer"
pass "exception renderer shows none/reason/by/created"
pass "README documents exception overlays in explain"

echo
echo "bashqueues QID explain exception static tests: OK"
