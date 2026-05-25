#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

fail() { echo "[FAIL] $*" >&2; exit 1; }
pass() { echo "[PASS] $*"; }

count_def() {
    local name="$1"
    grep -c "^${name}()" queuebash.sh || true
}

[[ "$(count_def queue)" == "1" ]] || fail "expected exactly one queue() dispatcher"
[[ "$(count_def _queue_home_for_user)" == "1" ]] || fail "expected exactly one _queue_home_for_user()"
[[ "$(count_def _queue_root_for_user)" == "1" ]] || fail "expected exactly one _queue_root_for_user()"
[[ "$(count_def _queue_user_exists)" == "1" ]] || fail "expected exactly one _queue_user_exists()"
[[ "$(count_def _queue_select_user_queue)" == "1" ]] || fail "expected exactly one _queue_select_user_queue()"
[[ "$(grep -c '^_queue_selected_user_for_display()' queuebash.sh || true)" == "1" ]] || fail "expected exactly one _queue_selected_user_for_display()"

grep -q 'QUEUEBASH_VERSION="0.17.16"' queuebash.sh || fail "queuebash version not bumped to 0.17.16"

pass "selected-user helper definitions are singleton-clean"
