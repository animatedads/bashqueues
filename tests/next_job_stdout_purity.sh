#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_RUNNER=direct
export QUEUEBASH_GZIP_LOGS=0
export QUEUEBASH_PLUGIN_SOURCE_DIR="$repo_root/assets.d"
export QUEUEBASH_CLASS_SOURCE_DIR="$repo_root/classes"
export QUEUEBASH_TRACE_DISPATCH=1

source "$repo_root/queuebash.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
_queue_init

fail() {
    echo "[FAIL] $1" >&2
    echo "--- selected ---" >&2
    printf '%s\n' "${selected:-}" >&2 || true
    echo "--- trace ---" >&2
    queue dispatch-trace >&2 || true
    find "$QUEUEBASH_ROOT" -maxdepth 5 -print -exec sh -c 'test -f "$1" && echo "### $1" && sed -n "1,120p" "$1"' _ {} \; >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

# Plugin deliberately prints success output on stdout.
cat > "$QUEUEBASH_ROOT/assets.d/noisy.sh" <<'PLUGIN'
queue_asset_facilities() {
    echo "noisy:ok    Emits stdout while allowing dispatch"
}

queue_asset_check_noisy_ok() {
    local token="$1" target="$2"
    shift 2 || true
    echo "asset_check_ok: noisy stdout target=$target"
    return 0
}
PLUGIN

queue assets validate >/dev/null || fail "noisy plugin should validate"

cat > "$QUEUEBASH_ROOT/classes/NOISY.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
queue_class_shared_asset noisy ok "target:with:colons,and,commas"
CLASS

queue submit noisy_job --class NOISY -- bash -c 'echo noisy-job' >/dev/null
qid="$(grep -l '^JOB_NAME=noisy_job$' "$QUEUEBASH_ROOT"/pending/*.job | head -1 | xargs -r basename | sed 's/\.job$//')"
[[ -n "$qid" ]] || fail "noisy_job not submitted"

selected="$(_queue_next_job)"

[[ "$selected" == "$QUEUEBASH_ROOT/pending/$qid.job" ]] || fail "_queue_next_job stdout should be only selected job path"

if grep -q 'asset_check_ok' <<< "$selected"; then
    fail "_queue_next_job stdout was contaminated by plugin output"
fi

trace="$(queue dispatch-trace || true)"
grep -q "class output $qid: asset_check_ok: noisy stdout" <<< "$trace" || fail "plugin output should be visible in trace"
grep -q "selected $qid" <<< "$trace" || fail "trace missing selected"

pass "_queue_next_job stdout is path-only"
pass "plugin stdout is captured into dispatch trace"

echo
echo "bashqueues next-job stdout purity tests: OK"
