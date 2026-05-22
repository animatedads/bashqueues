#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source "$repo_root/queuebash.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp"

queue submit testls -- echo one >/dev/null
queue submit testls -- echo two >/dev/null
queue submit failer -- definitely_not_a_command_12345 >/dev/null

queue priority testls 100 >/dev/null
queue --dryrun pause testls >/dev/null
queue pause testls >/dev/null
queue unpause testls >/dev/null

queue run --workers 2 >/dev/null || true

queue resubmit failer >/dev/null
queue --dryrun cancel failer >/dev/null || true
queue stats >/dev/null
queue version >/dev/null
queue events --tail 10 >/dev/null

echo "bashqueues selftest: OK"


# Retry behaviour
mkdir -p "$tmp/retry"
cat > "$tmp/retry/flaky.sh" <<'EOS'
#!/usr/bin/env bash
count_file="$1"
count="$(cat "$count_file" 2>/dev/null || echo 0)"
count=$((count + 1))
echo "$count" > "$count_file"
[[ "$count" -ge 2 ]]
EOS
chmod +x "$tmp/retry/flaky.sh"
queue submit retryonce --retries 1 --backoff 0 -- "$tmp/retry/flaky.sh" "$tmp/retry/count" >/dev/null
queue run >/dev/null || true
queue run >/dev/null || true
grep -q '^2$' "$tmp/retry/count"



# Detached worker behaviour
queue submit slowish -- bash -c 'sleep 0.2; echo detached-ok' >/dev/null
queue start --workers 1 >/tmp/qb_start_test.out
grep -q 'Detached workers started' /tmp/qb_start_test.out
for i in $(seq 1 30); do
    if queue list --state done | grep -q slowish; then
        break
    fi
    sleep 0.1
done
queue list --state done | grep -q slowish


# Final core conveniences
queue submit finalprio --max-log-size 1M -- echo final >/dev/null
queue dynamic-prio finalprio 88 >/dev/null
queue run >/dev/null
queue show finalprio >/tmp/qb_finalprio_show.txt
grep -q '^DURATION_SECONDS=' "$QUEUEBASH_ROOT"/done/*.job
grep -q '^LOG_BYTES=' "$QUEUEBASH_ROOT"/done/*.job


# Resource limit metadata/check command. Availability depends on user systemd session.
queue limits >/tmp/qb_limits_test.out 2>&1 || true
grep -q 'resource limits:' /tmp/qb_limits_test.out
queue submit limitmeta --cpu 50 --mem 128M -- echo limited >/dev/null
grep -q '^CPU_LIMIT=50$' "$QUEUEBASH_ROOT"/pending/*.job
grep -q '^MEM_LIMIT=128M$' "$QUEUEBASH_ROOT"/pending/*.job


# Cancellation must not run ON_FAILURE.
rm -f /tmp/qb_cancel_hook_ran
queue submit cancelhooktest -- bash -c 'sleep 5' >/dev/null
queue onfailure cancelhooktest -- bash -c 'echo bad >/tmp/qb_cancel_hook_ran' >/dev/null
queue start >/dev/null
for i in $(seq 1 50); do
    if queue list --state running | grep -q cancelhooktest; then
        break
    fi
    sleep 0.05
done
queue cancel cancelhooktest >/dev/null || true
sleep 0.3
[[ ! -f /tmp/qb_cancel_hook_ran ]]
queue list --state cancelled | grep -q cancelhooktest
rm -f /tmp/qb_cancel_hook_ran

# Full regression: tests/regression.sh
# Heavy log stress: tests/stress_logstorm.sh 1000000


# clear_cancelled_smoke
tmp_qb_cc="$(mktemp -d)"
old_qbr="${QUEUEBASH_ROOT:-}"
export QUEUEBASH_ROOT="$tmp_qb_cc"
queue submit clear_cancelled_smoke -- echo hello >/dev/null
queue cancel clear_cancelled_smoke >/dev/null || true
queue --dryrun clear cancelled >/dev/null
queue clear cancelled >/dev/null
rm -rf "$tmp_qb_cc"
if [[ -n "$old_qbr" ]]; then
    export QUEUEBASH_ROOT="$old_qbr"
else
    unset QUEUEBASH_ROOT
fi


# queuemgr_print_commands smoke
_queuemgr_print_commands >/tmp/qb_qmgr_help.txt
grep -q 'Clear/history' /tmp/qb_qmgr_help.txt
grep -q 'cc      clear cancelled' /tmp/qb_qmgr_help.txt


# systemd_wait_scope_regression
if grep -q -- '--scope --quiet --wait' "$PWD/queuebash.sh"; then
    echo "Invalid systemd-run combination still present: --scope --wait" >&2
    exit 1
fi


# limits_probe_command_smoke
queue limits >/tmp/qb_limits_basic.out 2>&1 || true
grep -q 'resource limits:' /tmp/qb_limits_basic.out
grep -q -- '--pipe --wait --collect' queuebash.sh


# health_interrupted_smoke
tmp_qb_health="$(mktemp -d)"
old_qbr="${QUEUEBASH_ROOT:-}"
export QUEUEBASH_ROOT="$tmp_qb_health"
queue submit health_interrupted_smoke -- sleep 1 >/dev/null
jobfile="$(find "$QUEUEBASH_ROOT/pending" -type f -name '*.job' | head -1)"
id="$(basename "$jobfile" .job)"
mkdir -p "$QUEUEBASH_ROOT/running" "$QUEUEBASH_ROOT/logs"
mv "$jobfile" "$QUEUEBASH_ROOT/running/$id.job"
{
    echo "RUN_PID=999999999"
    echo "RUN_PGID=999999999"
    echo "RUN_STARTED_AT=$(date -Is)"
} >> "$QUEUEBASH_ROOT/running/$id.job"
queue health --fix >/tmp/qb_health_fix.out
grep -q 'interrupted' /tmp/qb_health_fix.out
test -f "$QUEUEBASH_ROOT/interrupted/$id.job"
queue resubmit health_interrupted_smoke >/tmp/qb_resubmit_interrupted.out
grep -q 'Resubmitted' /tmp/qb_resubmit_interrupted.out
rm -rf "$tmp_qb_health"
if [[ -n "$old_qbr" ]]; then
    export QUEUEBASH_ROOT="$old_qbr"
else
    unset QUEUEBASH_ROOT
fi


# queuemgr_3col_smoke
_queuemgr_print_commands >/tmp/qb_qmgr_3col.txt
grep -q 'Run/workers' /tmp/qb_qmgr_3col.txt
grep -q 'Resubmit/recovery' /tmp/qb_qmgr_3col.txt
grep -q 'ci      clear interrupted' /tmp/qb_qmgr_3col.txt


# systemd_workdir_regression
grep -q -- '--working-directory' queuebash.sh
