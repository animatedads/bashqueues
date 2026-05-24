#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
fail(){ echo "[FAIL] $1" >&2; exit 1; }
pass(){ echo "[PASS] $1"; }

bash -n "$repo_root/queuebash.sh" || fail "queuebash syntax"

grep -q 'QUEUEBASH_SELECTED_ROOT' "$repo_root/queuebash.sh" || fail "selected root variable missing"
grep -q '_queue_root()' "$repo_root/queuebash.sh" || fail "_queue_root missing"
grep -q 'QUEUEBASH_SELECTED_ROOT:-' "$repo_root/queuebash.sh" || fail "_queue_root does not prefer selected root"
grep -q 'selected_root="${user_home}/.queuebash"' "$repo_root/queuebash.sh" || fail "selected root not derived from selected user's home"
grep -q 'export QUEUEBASH_SELECTED_ROOT="$selected_root"' "$repo_root/queuebash.sh" || fail "selected root not exported"
grep -q 'selected root:' "$repo_root/queuebash.sh" || fail "queue-user diagnostic missing selected root"
grep -q 'Queue user root selection safety' "$repo_root/README.md" || fail "README docs missing"

# Runtime smoke against the current user: selected root should be current user's passwd home, not cwd/root.
current_user="$(id -un)"
expected_home="$(getent passwd "$current_user" | awk -F: 'NR == 1 { print $6 }')"
out="$(
  QUEUEBASH_ALLOW_NONINTERACTIVE=1 bash -lc "source '$repo_root/queuebash.sh'; queue --queue-user '$current_user' queue-user" 2>&1
)"
echo "$out" | grep -q "selected user: $current_user" || fail "selected user diagnostic wrong"
echo "$out" | grep -q "queue root:    $expected_home/.queuebash" || {
    echo "$out" >&2
    fail "queue root diagnostic wrong"
}

pass "--queue-user derives root from the selected user's passwd home"
pass "_queue_root prefers QUEUEBASH_SELECTED_ROOT"
pass "diagnostics expose selected root"

echo
echo "bashqueues queue-user root selection tests: OK"
