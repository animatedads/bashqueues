#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_RUNNER=direct
export QUEUEBASH_GZIP_LOGS=0
source "$repo_root/queuebash.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
mkdir -p "$QUEUEBASH_ROOT"
fail() {
    echo "[FAIL] $1" >&2
    queue list >&2 || true
    find "$QUEUEBASH_ROOT" -type f -name '*.job' -print -exec sh -c 'echo "### $1"; cat "$1"' _ {} \; >&2 || true
    find "$QUEUEBASH_ROOT/logs" -maxdepth 1 -type f -print -exec sh -c 'echo "### $1"; tail -80 "$1"' _ {} \; >&2 || true
    exit 1
}
pass() { echo "[PASS] $1"; }
queue submit noisy_stdout \
    --max-log-size 4K \
    --log-overflow stderr-only \
    -- bash -c 'for i in $(seq 1 1500); do echo "stdout-noise-$i"; done; echo "STDERR_SURVIVED_AFTER_STDOUT_CUTOFF" >&2; exit 0' >/dev/null
queue run >/dev/null || true
job="$(grep -l '^JOB_NAME=noisy_stdout$' "$QUEUEBASH_ROOT"/done/*.job | head -1)"
[[ -n "$job" ]] || fail "noisy_stdout did not finish as done"
grep -q '^EXIT_CODE=0$' "$job" || fail "job did not preserve exit code 0"
grep -q '^LOG_OVERFLOW=1$' "$job" || fail "job did not record LOG_OVERFLOW"
grep -q '^LOG_STDOUT_SUPPRESSED=1$' "$job" || fail "job did not record stdout suppression"
id="$(basename "$job" .job)"
log="$QUEUEBASH_ROOT/logs/$id.log"
[[ -f "$log" ]] || fail "plain log missing"
grep -q 'STDERR_SURVIVED_AFTER_STDOUT_CUTOFF' "$log" || fail "stderr after stdout cutoff was not preserved"
grep -q 'stdout is now suppressed' "$log" || fail "stdout suppression warning missing"
if grep -q 'LOG_OVERFLOW_ERROR.*terminating job' "$log"; then
    fail "stderr-only policy used old terminating overflow behaviour"
fi
pass "stdout is suppressed at first cutoff"
pass "stderr continues after stdout cutoff"
pass "job exit status is preserved"
echo
echo "bashqueues stderr-only log overflow tests: OK"
