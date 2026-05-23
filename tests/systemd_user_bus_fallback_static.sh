#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
fail(){ echo "[FAIL] $1" >&2; exit 1; }
pass(){ echo "[PASS] $1"; }

bash -n "$repo_root/queuebash.sh" || fail "queuebash syntax"

grep -q 'systemctl --user show-environment' "$repo_root/queuebash.sh" || fail "user bus probe missing"
grep -q 'XDG_RUNTIME_DIR}/bus' "$repo_root/queuebash.sh" || fail "bus socket check missing"
grep -q '_queue_systemd_user_service_status_text' "$repo_root/queuebash.sh" || fail "diagnostic status helper missing"
grep -q 'systemd_user_bus:' "$repo_root/queuebash.sh" || fail "job log bus diagnostic missing"
grep -q 'auto must fall back to direct' "$repo_root/queuebash.sh" || fail "auto fallback rationale missing"
grep -q 'User systemd bus fallback' "$repo_root/README.md" || fail "README fallback docs missing"

pass "systemd user support verifies real user bus"
pass "auto runner fallback is documented in code"
pass "job log includes systemd user bus diagnostics"

echo
echo "bashqueues systemd user bus fallback static tests: OK"
