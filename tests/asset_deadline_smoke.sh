#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source assets.d/deadline.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
mkdir -p "$QUEUEBASH_ROOT/pending" "$QUEUEBASH_ROOT/done" "$QUEUEBASH_ROOT/exceptions"

cat > "$QUEUEBASH_ROOT/done/old1.job" <<'JOB'
JOB_ID=old1
JOB_NAME=nightly-recon
EXEC_DURATION=3600
EXEC_FINISHED_AT=1777590000
JOB
cat > "$QUEUEBASH_ROOT/done/old2.job" <<'JOB'
JOB_ID=old2
JOB_NAME=nightly-recon
EXEC_DURATION=5400
EXEC_FINISHED_AT=1777590100
JOB
cat > "$QUEUEBASH_ROOT/done/old3.job" <<'JOB'
JOB_ID=old3
JOB_NAME=nightly-recon
EXEC_DURATION=7200
EXEC_FINISHED_AT=1777590200
JOB

cat > "$QUEUEBASH_ROOT/pending/job1.job" <<'JOB'
JOB_ID=job1
JOB_NAME=nightly-recon
PRIORITY=10
COMMAND=( bash run-recon.sh )
JOB

export QUEUEBASH_CLASS_JOB_ID=job1
export QUEUEBASH_CLASS_JOB_NAME=nightly-recon
export QUEUEBASH_COMMAND_COUNT=2
export QUEUEBASH_COMMAND_0=bash
export QUEUEBASH_COMMAND_1=run-recon.sh

queue_asset_check_deadline_monitor nightly drop_dead=105000 now_epoch=100000 margin_pct=0 min_samples=1 fallback_duration=30m warn_slack=3600 warn_priority=50 critical_priority=99 > "$tmp/monitor.out"
grep -q 'asset_check_ok: deadline:monitor' "$tmp/monitor.out" || { cat "$tmp/monitor.out" >&2; exit 1; }
grep -q '^PRIORITY=99$' "$QUEUEBASH_ROOT/pending/job1.job" || { cat "$QUEUEBASH_ROOT/pending/job1.job" >&2; exit 1; }
grep -q '^DEADLINE_ESCALATED_PRIORITY=99$' "$QUEUEBASH_ROOT/pending/job1.job" || { cat "$QUEUEBASH_ROOT/pending/job1.job" >&2; exit 1; }

export CLASS_DEADLINE_FALLBACK_ASSETS='snmp time:window'
queue_asset_check_deadline_panic nightly drop_dead=105000 now_epoch=100000 margin_pct=0 min_samples=1 fallback_duration=30m critical_priority=99 > "$tmp/panic.out"
grep -q 'deadline panic applied fallback asset exception asset=snmp' "$tmp/panic.out" || { cat "$tmp/panic.out" >&2; exit 1; }
grep -q $'^snmp\tdeadline panic:' "$QUEUEBASH_ROOT/exceptions/job1.env" || { cat "$QUEUEBASH_ROOT/exceptions/job1.env" >&2; exit 1; }
grep -q $'^time:window\tdeadline panic:' "$QUEUEBASH_ROOT/exceptions/job1.env" || { cat "$QUEUEBASH_ROOT/exceptions/job1.env" >&2; exit 1; }

# Extra worker escalation is opt-in and bounded.  Simulate a saturated queue by
# recording one live worker and one running job, then let the deadline asset start
# exactly one helper worker after critical escalation.
mkdir -p "$QUEUEBASH_ROOT/workers" "$QUEUEBASH_ROOT/running"
cat > "$QUEUEBASH_ROOT/running/busy.job" <<'JOB'
JOB_ID=busy
JOB_NAME=busy-render
JOB
echo "$$" > "$QUEUEBASH_ROOT/workers/worker_fake.pid"
_queue_worker() { sleep 5; }
export -f _queue_worker 2>/dev/null || true

queue_asset_check_deadline_monitor nightly drop_dead=105000 now_epoch=100000 margin_pct=0 min_samples=1 fallback_duration=30m warn_slack=3600 warn_priority=50 critical_priority=99 start_worker=1 start_worker_slack=0 max_extra_workers=1 > "$tmp/worker.out"
grep -q 'deadline started extra worker' "$tmp/worker.out" || { cat "$tmp/worker.out" >&2; exit 1; }
grep -q '^DEADLINE_EXTRA_WORKER_PID=' "$QUEUEBASH_ROOT/pending/job1.job" || { cat "$QUEUEBASH_ROOT/pending/job1.job" >&2; exit 1; }
extra_pid="$(cat "$QUEUEBASH_ROOT/workers/deadline_extra_job1.pid")"
[[ "$extra_pid" =~ ^[0-9]+$ ]] || { cat "$tmp/worker.out" >&2; exit 1; }
kill "$extra_pid" >/dev/null 2>&1 || true
wait "$extra_pid" >/dev/null 2>&1 || true

echo "[PASS] deadline asset boosts priority, applies fallbacks, and can start a bounded extra worker"
