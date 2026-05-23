#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
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

qid_of_name_state() {
    local name="$1"
    local state="$2"
    local f
    for f in "$QUEUEBASH_ROOT/$state"/*.job; do
        [[ -e "$f" ]] || continue
        grep -q "^JOB_NAME=$name$" "$f" && basename "$f" .job && return 0
    done
    return 1
}

wait_for_state() {
    local name="$1"
    local state="$2"
    local tries="${3:-80}"

    for _ in $(seq 1 "$tries"); do
        if queue list --state "$state" | grep -q "[[:space:]]$name[[:space:]]"; then
            return 0
        fi
        sleep 0.05
    done

    fail "job '$name' did not reach state '$state'"
}

# For tests that intentionally leave jobs blocked, never call queue run raw.
run_queue_bounded() {
    timeout 2s bash -lc '
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
# 1. Retroactive satisfaction:
#    A dependency on a job that is already done is immediately satisfied.
# -------------------------------------------------------------------

queue submit ancestor_job -- bash -c 'echo ancestor > "$QUEUEBASH_ROOT/ancestor.ran"' >/dev/null
run_queue_bounded

wait_for_state ancestor_job done
[[ -f "$QUEUEBASH_ROOT/ancestor.ran" ]] || fail "ancestor did not run"

queue submit descendant_job --after-success ancestor_job -- bash -c 'echo descendant > "$QUEUEBASH_ROOT/descendant.ran"' >/dev/null
run_queue_bounded

wait_for_state descendant_job done
[[ -f "$QUEUEBASH_ROOT/descendant.ran" ]] || fail "retroactive dependent did not run"

pass "retroactive already-done dependency is satisfied"

# -------------------------------------------------------------------
# 2. Duplicate ancestor names:
#    Name dependency is historical/name-based. A done alpha_task satisfies
#    charlie_task even if another alpha_task exists later.
# -------------------------------------------------------------------

queue submit alpha_task -- bash -c 'echo old-alpha > "$QUEUEBASH_ROOT/old_alpha.ran"' >/dev/null
run_queue_bounded
wait_for_state alpha_task done

queue submit alpha_task -- bash -c 'echo new-alpha > "$QUEUEBASH_ROOT/new_alpha.ran"' >/dev/null
queue submit charlie_by_name --after-success alpha_task -- bash -c 'echo charlie > "$QUEUEBASH_ROOT/charlie_name.ran"' >/dev/null

run_queue_twice

wait_for_state charlie_by_name done
[[ -f "$QUEUEBASH_ROOT/charlie_name.ran" ]] || fail "name dependency did not satisfy against historical done alpha"

pass "duplicate-name dependency uses historical exact name satisfaction"

# -------------------------------------------------------------------
# 3. Strict QID dependency:
#    A dependent using an exact QID waits for that exact job.
# -------------------------------------------------------------------

queue submit alpha_strict -- bash -c 'echo strict-alpha > "$QUEUEBASH_ROOT/strict_alpha.ran"' >/dev/null
strict_alpha_qid="$(qid_of_name_state alpha_strict pending)"
[[ -n "$strict_alpha_qid" ]] || fail "strict alpha pending qid not found"

queue submit charlie_by_qid --after-success "$strict_alpha_qid" -- bash -c 'echo strict-charlie > "$QUEUEBASH_ROOT/charlie_qid.ran"' >/dev/null

run_queue_twice

wait_for_state alpha_strict done
wait_for_state charlie_by_qid done
[[ -f "$QUEUEBASH_ROOT/charlie_qid.ran" ]] || fail "QID dependent did not run after exact parent"

queue deps charlie_by_qid > "$tmp/deps_qid.txt"
grep -q "$strict_alpha_qid:done" "$tmp/deps_qid.txt" || fail "QID dependency was not reported done"

pass "QID dependency tracks exact ancestor"

# -------------------------------------------------------------------
# 4. Fan-in:
#    Final job waits for all branches to be done.
# -------------------------------------------------------------------

queue submit branch_1 -- bash -c 'echo b1 > "$QUEUEBASH_ROOT/branch_1.ran"' >/dev/null
queue submit branch_2 -- bash -c 'echo b2 > "$QUEUEBASH_ROOT/branch_2.ran"' >/dev/null
queue submit branch_3 -- bash -c 'echo b3 > "$QUEUEBASH_ROOT/branch_3.ran"' >/dev/null
queue submit final_merge \
    --after-success branch_1 \
    --after-success branch_2 \
    --after-success branch_3 \
    -- bash -c 'cat "$QUEUEBASH_ROOT"/branch_*.ran > "$QUEUEBASH_ROOT/final_merge.ran"'

run_queue_twice

wait_for_state branch_1 done
wait_for_state branch_2 done
wait_for_state branch_3 done
wait_for_state final_merge done

grep -q 'b1' "$QUEUEBASH_ROOT/final_merge.ran" || fail "fan-in output missing branch_1"
grep -q 'b2' "$QUEUEBASH_ROOT/final_merge.ran" || fail "fan-in output missing branch_2"
grep -q 'b3' "$QUEUEBASH_ROOT/final_merge.ran" || fail "fan-in output missing branch_3"

pass "fan-in waits for all dependencies"

# -------------------------------------------------------------------
# 5. Failed parent blocks child:
#    The child remains pending and queue waiting reports blocked.
# -------------------------------------------------------------------

queue submit doomed_parent -- bash -c 'exit 42' >/dev/null
queue submit trapped_child --after-success doomed_parent -- bash -c 'echo should-not-run > "$QUEUEBASH_ROOT/trapped.ran"' >/dev/null

run_queue_bounded

wait_for_state doomed_parent failed
wait_for_state trapped_child pending
[[ ! -f "$QUEUEBASH_ROOT/trapped.ran" ]] || fail "trapped child ran despite failed parent"

queue waiting > "$tmp/waiting_failed.txt"
grep -q 'doomed_parent:blocked' "$tmp/waiting_failed.txt" || fail "failed parent was not reported blocked"

pass "failed parent blocks dependent child"

# -------------------------------------------------------------------
# 6. Circular dependency:
#    Safe deadlock. Jobs stay pending; worker does not spin/crash.
#    This case is intentionally last because blocked jobs remain pending.
# -------------------------------------------------------------------

queue submit ouroboros_1 --after-success ouroboros_2 -- bash -c 'echo bad1 > "$QUEUEBASH_ROOT/ouro1.ran"' >/dev/null
queue submit ouroboros_2 --after-success ouroboros_1 -- bash -c 'echo bad2 > "$QUEUEBASH_ROOT/ouro2.ran"' >/dev/null

run_queue_bounded

wait_for_state ouroboros_1 pending
wait_for_state ouroboros_2 pending
[[ ! -f "$QUEUEBASH_ROOT/ouro1.ran" ]] || fail "cycle job 1 ran"
[[ ! -f "$QUEUEBASH_ROOT/ouro2.ran" ]] || fail "cycle job 2 ran"

queue waiting > "$tmp/waiting_cycle.txt"
grep -q 'ouroboros_1:waiting\|ouroboros_1:blocked' "$tmp/waiting_cycle.txt" || fail "cycle waiting status missing ouroboros_1"
grep -q 'ouroboros_2:waiting\|ouroboros_2:blocked' "$tmp/waiting_cycle.txt" || fail "cycle waiting status missing ouroboros_2"

pass "circular dependency remains safely pending"

echo
echo "bashqueues dependency edge-case tests: OK"
