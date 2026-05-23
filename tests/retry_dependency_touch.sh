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

source_file="$tmp/input.txt"
produced_file="$tmp/produced.txt"
dependent_output="$tmp/dependent_output.txt"

pass() { printf '[PASS] %s\n' "$1"; }

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    printf '\n--- queue list ---\n' >&2
    queue list >&2 || true
    printf '\n--- queue waiting ---\n' >&2
    queue waiting >&2 || true
    printf '\n--- queue events ---\n' >&2
    queue events 60 >&2 || true
    printf '\n--- job files ---\n' >&2
    find "$QUEUEBASH_ROOT" -type f -name '*.job' -print -exec sh -c 'echo "### $1"; cat "$1"' _ {} \; >&2 || true
    printf '\n--- logs ---\n' >&2
    find "$QUEUEBASH_ROOT/logs" -type f -print -exec sh -c 'echo "### $1"; case "$1" in *.gz) gzip -cd "$1" | tail -120 ;; *) tail -120 "$1" ;; esac' _ {} \; >&2 || true
    exit 1
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

queue submit producer \
    --retries 1 \
    --backoff 0 \
    --on-retry-failure bash -c "echo recovered-by-on-retry-failure > '$source_file'" \
    -- bash -c "test -f '$source_file' && cat '$source_file' > '$produced_file'"

# Verify submit persisted the hook before running.
producer_job="$(grep -l '^JOB_NAME=producer$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
grep -q '^ON_RETRY_FAILURE=(' "$producer_job" || fail "ON_RETRY_FAILURE was not persisted to producer job"

queue submit dependent \
    --after-success producer \
    -- bash -c "cat '$produced_file' > '$dependent_output'"

run_queue_twice

[[ -f "$source_file" ]] || fail "on-retry-failure hook did not create source file"
grep -q 'recovered-by-on-retry-failure' "$source_file" || fail "source file does not contain hook-created data"

[[ -f "$produced_file" ]] || fail "producer did not create produced.txt after retry"
grep -q 'recovered-by-on-retry-failure' "$produced_file" || fail "producer output does not contain recovered data"

[[ -f "$dependent_output" ]] || fail "dependent did not cat produced.txt"
grep -q 'recovered-by-on-retry-failure' "$dependent_output" || fail "dependent output does not contain recovered data"

wait_for_state producer done
wait_for_state dependent done

queue deps dependent > "$tmp/deps.txt"
grep -q 'producer:done' "$tmp/deps.txt" || fail "dependent dependency was not marked done"

producer_job="$(grep -l '^JOB_NAME=producer$' "$QUEUEBASH_ROOT"/done/*.job | head -1)"
grep -q '^RETRIES_DONE=1$' "$producer_job" || fail "producer did not record RETRIES_DONE=1"

# The remediation hook belongs to the failed first attempt, while the final
# producer job is the successful retry. Search the producer attempt log chain.
: > "$tmp/producer_chain.log"

for producer_attempt in "$QUEUEBASH_ROOT"/failed/*.job "$QUEUEBASH_ROOT"/done/*.job; do
    [[ -e "$producer_attempt" ]] || continue
    grep -q '^JOB_NAME=producer$' "$producer_attempt" || continue

    attempt_id="$(basename "$producer_attempt" .job)"
    attempt_log="$QUEUEBASH_ROOT/logs/$attempt_id.log"
    attempt_log_gz="$QUEUEBASH_ROOT/logs/$attempt_id.log.gz"

    if [[ -f "$attempt_log_gz" ]]; then
        gzip -cd "$attempt_log_gz" >> "$tmp/producer_chain.log"
    elif [[ -f "$attempt_log" ]]; then
        cat "$attempt_log" >> "$tmp/producer_chain.log"
    fi
done

grep -q 'on-retry-failure hook' "$tmp/producer_chain.log" || fail "producer log chain does not show on-retry-failure hook"
grep -q 'scheduled retry' "$tmp/producer_chain.log" || grep -q 'retry_scheduled' "$QUEUEBASH_ROOT/events.jsonl" || fail "producer logs/events do not show retry"

pass "on-retry-failure hook created missing input"
pass "producer retried and succeeded"
pass "dependent after-success job cat output"
pass "retry preserved dependency release"

echo
echo "bashqueues retry dependency touch test: OK"
