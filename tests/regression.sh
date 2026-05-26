#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
# General regression tests queue semantics; keep systemd-specific tests separate.
export QUEUEBASH_RUNNER=direct
source "$repo_root/queuebash.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"; rm -f /tmp/qb_cancel_hook_ran /tmp/qb_fail_hook_ran /tmp/qb_success_hook_ran' EXIT

export QUEUEBASH_ROOT="$tmp/q"
mkdir -p "$QUEUEBASH_ROOT"

pass() { printf '[PASS] %s\n' "$1"; }
fail() { printf '[FAIL] %s\n' "$1" >&2; exit 1; }

wait_for_job_state() {
    local name="$1" state="$2" tries="${3:-200}" delay="${4:-0.05}"

    for _ in $(seq 1 "$tries"); do
        if queue list --state "$state" | grep -q "[[:space:]]$name[[:space:]]"; then
            return 0
        fi
        sleep "$delay"
    done

    echo "Job $name not found in state $state after $tries tries" >&2
    echo "--- queue list all ---" >&2
    queue list --state all >&2 || true

    echo "--- matching job files and logs ---" >&2
    find "$QUEUEBASH_ROOT" -type f -name '*.job' -print 2>/dev/null | while read -r jf; do
        if grep -q "^JOB_NAME=$name$" "$jf" 2>/dev/null; then
            echo "### $jf" >&2
            cat "$jf" >&2
            jid="$(basename "$jf" .job)"
            if [[ -f "$QUEUEBASH_ROOT/logs/$jid.log" ]]; then
                echo "--- log tail: $jid ---" >&2
                tail -80 "$QUEUEBASH_ROOT/logs/$jid.log" >&2 || true
            fi
        fi
    done

    return 1
}

queue version | grep -q 'queuebash' || fail "queue version"
queue --help | grep -q 'queue submit' || fail "queue help"
pass "version/help"

queue submit capture_ok -- "$repo_root/tests/emit_stdout_stderr.sh" alpha beta >/dev/null
queue run >/dev/null
wait_for_job_state capture_ok done 300 0.05
ok_job="$(grep -l '^JOB_NAME=capture_ok$' "$QUEUEBASH_ROOT"/done/*.job)"
ok_id="$(basename "$ok_job" .job)"
ok_log="$QUEUEBASH_ROOT/logs/$ok_id.log"
grep -q 'STDOUT: hello from stdout' "$ok_log" || fail "stdout capture"
grep -q 'STDERR: hello from stderr' "$ok_log" || fail "stderr capture"
grep -q '^EXIT_CODE=0$' "$ok_job" || fail "exit summary rc 0"
grep -q '^DURATION_SECONDS=' "$ok_job" || fail "duration summary"
pass "stdout/stderr capture and rc 0"

rm -f /tmp/qb_fail_hook_ran
queue submit capture_fail --on-failure "$repo_root/tests/write_marker.sh" /tmp/qb_fail_hook_ran failhook -- "$repo_root/tests/fail_with_output.sh" >/dev/null
queue run >/dev/null || true
wait_for_job_state capture_fail failed 300 0.05
fail_job="$(grep -l '^JOB_NAME=capture_fail$' "$QUEUEBASH_ROOT"/failed/*.job)"
fail_id="$(basename "$fail_job" .job)"
fail_log="$QUEUEBASH_ROOT/logs/$fail_id.log"
grep -q 'STDOUT: about to fail' "$fail_log" || fail "fail stdout capture"
grep -q 'STDERR: failing intentionally' "$fail_log" || fail "fail stderr capture"
grep -q '^EXIT_CODE=23$' "$fail_job" || fail "exit summary rc 23"
grep -q 'failhook' /tmp/qb_fail_hook_ran || fail "ON_FAILURE hook"
pass "non-zero rc and failure hook"

rm -f /tmp/qb_success_hook_ran
queue submit hook_success --on-success "$repo_root/tests/write_marker.sh" /tmp/qb_success_hook_ran okhook -- echo main >/dev/null
queue run >/dev/null
wait_for_job_state hook_success done 300 0.05
grep -q 'okhook' /tmp/qb_success_hook_ran || fail "ON_SUCCESS hook"
pass "success hook"

queue submit prio_low --priority 1 -- echo low >/dev/null
queue submit prio_hi --priority 1 -- echo high >/dev/null
queue dynamic-prio prio_hi 99 >/dev/null
queue --dryrun run > "$tmp/dryrun.txt"
grep -q 'prio_hi' "$tmp/dryrun.txt" || fail "dryrun next priority"
queue run >/dev/null
wait_for_job_state prio_hi done
wait_for_job_state prio_low done
pass "dynamic priority and dryrun run"

queue submit statejob -- echo state >/dev/null
queue pause statejob >/dev/null
wait_for_job_state statejob paused
queue unpause statejob >/dev/null
wait_for_job_state statejob pending
queue delete statejob >/dev/null
wait_for_job_state statejob deleted
queue undelete statejob >/dev/null
wait_for_job_state statejob pending
queue run >/dev/null
wait_for_job_state statejob done
pass "pause/unpause/delete/undelete"

queue submit detached_sleep -- "$repo_root/tests/sleepy.sh" 1 >/dev/null
queue start >/tmp/qb_start.out
grep -q 'Detached workers started' /tmp/qb_start.out || fail "detached start output"
wait_for_job_state detached_sleep done 120
pass "background detached worker"

rm -f /tmp/qb_cancel_hook_ran
queue submit cancelhooktest -- "$repo_root/tests/sleepy.sh" 8 >/dev/null
queue onfailure cancelhooktest -- "$repo_root/tests/write_marker.sh" /tmp/qb_cancel_hook_ran bad >/dev/null
queue start >/dev/null
wait_for_job_state cancelhooktest running 120
queue --dryrun cancel cancelhooktest > "$tmp/cancel_dry.txt"
grep -q 'DRYRUN: would signal' "$tmp/cancel_dry.txt" || fail "cancel dryrun"
queue cancel cancelhooktest >/dev/null || true
wait_for_job_state cancelhooktest cancelled 120
sleep 0.2
[[ ! -f /tmp/qb_cancel_hook_ran ]] || fail "cancel ran ON_FAILURE"
pass "cancel without failure hook"

queue submit killtree -- "$repo_root/tests/spawn_child_sleep.sh" 8 >/dev/null
queue start >/dev/null
wait_for_job_state killtree running 120
queue pids killtree > "$tmp/pids.txt" || true
grep -q 'Recorded RUN_PID:' "$tmp/pids.txt" || fail "pids report"
queue kill killtree >/dev/null || true
wait_for_job_state killtree cancelled 120
pass "kill process-tree path"

queue submit flaky --retries 1 --backoff 0 -- "$repo_root/tests/flaky_once.sh" "$tmp/flaky.count" >/dev/null
queue run >/dev/null || true
queue run >/dev/null || true
grep -q '^2$' "$tmp/flaky.count" || fail "retry count"
queue list --state done | grep -q flaky || fail "flaky done after retry"
pass "automatic retry"

queue submit resub_fail -- "$repo_root/tests/fail_with_output.sh" >/dev/null
queue run >/dev/null || true
wait_for_job_state resub_fail failed
queue --dryrun resubmit resub_fail | grep -q 'DRYRUN' || fail "resubmit dryrun"
queue resubmit resub_fail >/dev/null
wait_for_job_state resub_fail pending
pass "resubmit failed job"

lines="${QB_REGRESSION_LINES:-10000}"
queue submit logstorm --max-log-size 50M -- "$repo_root/tests/line_storm.sh" "$lines" >/dev/null
queue run >/dev/null
wait_for_job_state logstorm done 160
storm_job="$(grep -l '^JOB_NAME=logstorm$' "$QUEUEBASH_ROOT"/done/*.job)"
storm_id="$(basename "$storm_job" .job)"
storm_log="$QUEUEBASH_ROOT/logs/$storm_id.log"
grep -q "LINE $lines stdout" "$storm_log" || fail "logstorm final stdout line"
grep -q 'stderr checkpoint' "$storm_log" || fail "logstorm stderr checkpoint"
grep -q '^LOG_BYTES=' "$storm_job" || fail "logstorm summary"
pass "moderate high-volume stdout/stderr capture ($lines lines)"

queue stats > "$tmp/stats.txt"
grep -q 'done:' "$tmp/stats.txt" || fail "stats"
queue events --tail 20 > "$tmp/events.txt"
grep -q '"event"' "$tmp/events.txt" || fail "events"
timeout 1 queue tail capture_ok >/tmp/qb_tail_smoke.out 2>&1 || true
grep -q 'tailing:' /tmp/qb_tail_smoke.out || fail "tail command"
pass "stats/events/tail"

queue limits >/tmp/qb_limits_test.out 2>&1 || true
grep -q 'resource limits:' /tmp/qb_limits_test.out || fail "queue limits"
queue submit limitmeta --cpu 50 --mem 128M -- echo limited >/dev/null
grep -q '^CPU_LIMIT=50$' "$QUEUEBASH_ROOT"/pending/*.job || fail "cpu metadata"
grep -q '^MEM_LIMIT=128M$' "$QUEUEBASH_ROOT"/pending/*.job || fail "mem metadata"
pass "resource metadata/limits command"

timeout 2 queue watch --interval 1 >/tmp/qb_watch_smoke.out 2>&1 || true
grep -Eq 'Queue statistics|queuebash watch' /tmp/qb_watch_smoke.out || fail "watch smoke"
pass "watch mode smoke"

echo
echo "bashqueues full regression: OK"
