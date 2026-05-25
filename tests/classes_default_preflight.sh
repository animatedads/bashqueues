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
_queue_init

fail() {
    echo "[FAIL] $1" >&2
    queue list >&2 || true
    find "$QUEUEBASH_ROOT" -maxdepth 4 -print >&2 || true
    find "$QUEUEBASH_ROOT" -type f -name '*.job' -print -exec cat {} \; >&2 || true
    [[ -f "$QUEUEBASH_ROOT/events.jsonl" ]] && cat "$QUEUEBASH_ROOT/events.jsonl" >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

[[ -f "$QUEUEBASH_ROOT/classes/DEFAULT.env" ]] || fail "DEFAULT class file was not created"

queue submit no_class -- bash -c 'echo no-class-ran' >/dev/null
job="$(grep -l '^JOB_NAME=no_class$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
[[ -n "$job" ]] || fail "no_class pending job missing"
grep -q '^JOB_CLASS=DEFAULT$' "$job" || fail "unclassified job did not record JOB_CLASS=DEFAULT"

queue run >/dev/null || true
done_job="$(grep -l '^JOB_NAME=no_class$' "$QUEUEBASH_ROOT"/done/*.job | head -1)"
[[ -n "$done_job" ]] || fail "default-class job did not run"

mkdir -p "$QUEUEBASH_ROOT/class.d"
cat > "$QUEUEBASH_ROOT/class.d/gate.sh" <<'PLUGIN'
check_gate_ready() {
    [[ -f "$QUEUEBASH_ROOT/gate.open" ]]
}
PLUGIN

cat > "$QUEUEBASH_ROOT/classes/GATED.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_PREFLIGHT_PLUGINS="gate.sh"
CLASS_PREFLIGHT_FUNC="check_gate_ready"
CLASS_EXCLUSIVE_ASSETS="gate:test"
CLASS

queue submit gated --class GATED -- bash -c 'echo gated-ran' >/dev/null
pending_job="$(grep -l '^JOB_NAME=gated$' "$QUEUEBASH_ROOT"/pending/*.job 2>/dev/null | head -1 || true)"
[[ -n "$pending_job" ]] || fail "gated pending job missing"

if _queue_class_available "$pending_job"; then
    fail "gated class should not be available while gate is closed"
fi

[[ -f "$pending_job" ]] || fail "gated job should remain pending while gate is closed"
if grep -l '^JOB_NAME=gated$' "$QUEUEBASH_ROOT"/failed/*.job >/dev/null 2>&1; then
    fail "gated job incorrectly failed when resource unavailable"
fi
grep -q '"event":"resource_blocked"' "$QUEUEBASH_ROOT/events.jsonl" || fail "resource_blocked event missing"

touch "$QUEUEBASH_ROOT/gate.open"
queue run >/dev/null || true

gated_done="$(grep -l '^JOB_NAME=gated$' "$QUEUEBASH_ROOT"/done/*.job | head -1)"
[[ -n "$gated_done" ]] || fail "gated job did not run after gate opened"
gated_id="$(basename "$gated_done" .job)"
grep -q '^gated-ran$' "$QUEUEBASH_ROOT/logs/$gated_id.log" || fail "gated payload did not run"

pass "unclassified jobs use DEFAULT class"
pass "class preflight keeps unavailable job pending"
pass "class preflight allows job once resource becomes available"

echo
echo "bashqueues default class/preflight tests: OK"
