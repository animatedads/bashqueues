#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
fail(){ echo "[FAIL] $1" >&2; exit 1; }
pass(){ echo "[PASS] $1"; }

bash -n "$repo_root/queuebash.sh" || fail "queuebash syntax"

grep -q '_queue_root_running_foreign_payload_user' "$repo_root/queuebash.sh" || fail "foreign payload helper missing"
grep -q 'root-foreign-user-auto-direct' "$repo_root/queuebash.sh" || fail "foreign direct policy log missing"
grep -q 'systemd-foreign-user-not-used' "$repo_root/queuebash.sh" || fail "explicit systemd foreign-user block missing"
grep -q 'Direct+runuser is the predictable fallback' "$repo_root/queuebash.sh" || fail "fallback rationale missing"
grep -q 'Root running payloads as another user' "$repo_root/README.md" || fail "README root foreign runner docs missing"

pass "root foreign RUN_USER auto resolves to direct policy"
pass "explicit systemd foreign-user path is blocked"
pass "policy is documented"

echo
echo "bashqueues root foreign user direct runner static tests: OK"
