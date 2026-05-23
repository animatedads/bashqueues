#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

export QUEUEBASH_ALLOW_NONINTERACTIVE=1

# This test validates dependency scheduling. It intentionally avoids
# user-systemd behaviour, because systemd EXEC/session problems should not
# obscure dependency regressions.
export QUEUEBASH_RUNNER=direct

source "$repo_root/queuebash.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export QUEUEBASH_ROOT="$tmp/q"
mkdir -p "$QUEUEBASH_ROOT"

pass() { printf '[PASS] %s\n' "$1"; }

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    printf '\n--- queue list ---\n' >&2
    queue list >&2 || true
    printf '\n--- queue waiting ---\n' >&2
    queue waiting >&2 || true
    printf '\n--- job files ---\n' >&2
    find "$QUEUEBASH_ROOT" -type f -name '*.job' -print -exec sh -c 'echo "### $1"; cat "$1"' _ {} \; >&2 || true
    printf '\n--- logs ---\n' >&2
    find "$QUEUEBASH_ROOT/logs" -type f -print -exec sh -c 'echo "### $1"; case "$1" in *.gz) gzip -cd "$1" | tail -80 ;; *) tail -80 "$1" ;; esac' _ {} \; >&2 || true
    exit 1
}

submit_qid() {
    local out
    out="$(queue submit "$@")"
    printf '%s\n' "$out" >&2
    printf '%s\n' "$out" | awk '/^Submitted / { print $2; exit }'
}

wait_for_state() {
    local name="$1"
    local state="$2"
    local tries="${3:-120}"

    for _ in $(seq 1 "$tries"); do
        if queue list --state "$state" | grep -q "[[:space:]]$name[[:space:]]"; then
            return 0
        fi
        sleep 0.05
    done

    fail "job '$name' did not reach state '$state'"
}

run_queue_bounded() {
    # Do not let a test hang forever if worker loop semantics change.
    timeout 20s bash -lc '
        set -e
        export QUEUEBASH_ALLOW_NONINTERACTIVE=1
        export QUEUEBASH_RUNNER=direct
        export QUEUEBASH_ROOT="$1"
        source "$2/queuebash.sh"
        queue run >/dev/null || true
    ' _ "$QUEUEBASH_ROOT" "$repo_root" || true
}

run_queue_twice() {
    run_queue_bounded
    run_queue_bounded
}


# -------------------------------------------------------------------
# 0. Self-dependency is rejected at submit time.
# -------------------------------------------------------------------

if queue submit self_dep --after-success self_dep -- echo loop >/tmp/qb_selfdep.out 2>/tmp/qb_selfdep.err; then
    fail "self-dependency submit unexpectedly succeeded"
fi
grep -q 'job cannot depend on itself: self_dep' /tmp/qb_selfdep.err || fail "self-dependency error message missing"

pass "self-dependency is rejected"

# -------------------------------------------------------------------
# 1. Child submitted before parent must not run.
# -------------------------------------------------------------------

queue submit child_waits --after-success parent_ok -- bash -c 'echo child > "$QUEUEBASH_ROOT/child_waits.ran"' >/dev/null

run_queue_bounded

[[ ! -f "$QUEUEBASH_ROOT/child_waits.ran" ]] || fail "child ran before parent dependency completed"
queue waiting > "$tmp/waiting_name.txt"
grep -q 'parent_ok:waiting' "$tmp/waiting_name.txt" || fail "waiting dependency was not reported"

pass "child waits when dependency is missing"

# -------------------------------------------------------------------
# 2. Parent success releases child.
# -------------------------------------------------------------------

queue submit parent_ok -- bash -c 'echo parent > "$QUEUEBASH_ROOT/parent_ok.ran"' >/dev/null

run_queue_twice

[[ -f "$QUEUEBASH_ROOT/parent_ok.ran" ]] || fail "parent did not run"
[[ -f "$QUEUEBASH_ROOT/child_waits.ran" ]] || fail "child did not run after parent success"

wait_for_state parent_ok done
wait_for_state child_waits done

queue deps child_waits > "$tmp/deps_name.txt"
grep -q 'parent_ok:done' "$tmp/deps_name.txt" || fail "dependency was not marked done"

pass "after-success dependency releases after successful parent"

# -------------------------------------------------------------------
# 3. Failed parent blocks dependent child.
# -------------------------------------------------------------------

queue submit child_blocked --after-success parent_fails -- bash -c 'echo child > "$QUEUEBASH_ROOT/child_blocked.ran"' >/dev/null
queue submit parent_fails -- bash -c 'echo parent-fails >&2; exit 22' >/dev/null

run_queue_twice

[[ ! -f "$QUEUEBASH_ROOT/child_blocked.ran" ]] || fail "child ran despite failed dependency"

wait_for_state parent_fails failed
wait_for_state child_blocked pending

queue deps child_blocked > "$tmp/deps_failed.txt"
grep -q 'parent_fails:blocked' "$tmp/deps_failed.txt" || fail "failed dependency was not reported blocked"

pass "failed parent blocks dependent child"

# -------------------------------------------------------------------
# 4. QID dependency works.
# -------------------------------------------------------------------

qid_parent="$(submit_qid parent_by_qid -- bash -c 'echo qid-parent > "$QUEUEBASH_ROOT/qid_parent.ran"')"

queue submit child_by_qid --after-success "$qid_parent" -- bash -c 'echo qid-child > "$QUEUEBASH_ROOT/qid_child.ran"' >/dev/null

run_queue_twice

[[ -f "$QUEUEBASH_ROOT/qid_parent.ran" ]] || fail "QID parent did not run"
[[ -f "$QUEUEBASH_ROOT/qid_child.ran" ]] || fail "QID child did not run"

wait_for_state parent_by_qid done
wait_for_state child_by_qid done

queue deps child_by_qid > "$tmp/deps_qid.txt"
grep -q "$qid_parent:done" "$tmp/deps_qid.txt" || fail "QID dependency did not report done"

pass "QID dependency works"

# -------------------------------------------------------------------
# 5. Multiple dependencies all need success.
# -------------------------------------------------------------------

queue submit multi_child --after-success multi_a --after-success multi_b -- bash -c 'echo multi > "$QUEUEBASH_ROOT/multi_child.ran"' >/dev/null
queue submit multi_a -- bash -c 'echo a > "$QUEUEBASH_ROOT/multi_a.ran"' >/dev/null

run_queue_twice

[[ -f "$QUEUEBASH_ROOT/multi_a.ran" ]] || fail "multi_a did not run"
[[ ! -f "$QUEUEBASH_ROOT/multi_child.ran" ]] || fail "multi_child ran before multi_b"

queue waiting > "$tmp/waiting_multi.txt"
grep -q 'multi_b:waiting' "$tmp/waiting_multi.txt" || fail "multi_b was not reported waiting"

queue submit multi_b -- bash -c 'echo b > "$QUEUEBASH_ROOT/multi_b.ran"' >/dev/null

run_queue_twice

[[ -f "$QUEUEBASH_ROOT/multi_b.ran" ]] || fail "multi_b did not run"
[[ -f "$QUEUEBASH_ROOT/multi_child.ran" ]] || fail "multi_child did not run after all deps"

wait_for_state multi_a done
wait_for_state multi_b done
wait_for_state multi_child done

queue deps multi_child > "$tmp/deps_multi.txt"
grep -q 'multi_a:done' "$tmp/deps_multi.txt" || fail "multi_a not done in deps"
grep -q 'multi_b:done' "$tmp/deps_multi.txt" || fail "multi_b not done in deps"

pass "multiple after-success dependencies work"

echo
echo "bashqueues after-success dependency tests: OK"
