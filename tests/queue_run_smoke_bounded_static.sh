#!/usr/bin/env bash
set -euo pipefail

fail() { echo "[FAIL] $1" >&2; exit 1; }

for t in tests/tail_options.sh tests/dispatch_trace_next_job_fix.sh; do
    [[ -f "$t" ]] || fail "missing $t"
    grep -q 'run_queue_bounded()' "$t" || fail "$t missing bounded queue-run helper"
    grep -q 'timeout 30s bash -lc' "$t" || fail "$t missing stage timeout"
    grep -q 'queue run --workers 1' "$t" || fail "$t must exercise explicit single-worker foreground path"
    if grep -En '^[[:space:]]*queue run( |>|$)' "$t" | grep -v -- 'queue run --workers 1' >/dev/null; then
        fail "$t contains raw unbounded queue run"
    fi
    grep -q 'queue run --workers 1 timed out or failed' "$t" || fail "$t missing actionable timeout failure"
done

printf '[PASS] queue-run smoke tests are bounded and exercise explicit single-worker mode\n'
