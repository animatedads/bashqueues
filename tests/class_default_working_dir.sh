#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_RUNNER=direct
export QUEUEBASH_GZIP_LOGS=0
export QUEUEBASH_PLUGIN_SOURCE_DIR="$repo_root/assets.d"
export QUEUEBASH_CLASS_SOURCE_DIR="$repo_root/classes"

source "$repo_root/queuebash.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
_queue_init

fail() {
    echo "[FAIL] $1" >&2
    find "$QUEUEBASH_ROOT" -maxdepth 4 -type f -print -exec sh -c 'echo "### $1"; sed -n "1,180p" "$1"' _ {} \; >&2 || true
    exit 1
}

pass(){ echo "[PASS] $1"; }

mkdir -p "$tmp/workdir"
cat > "$tmp/workdir/waiter.rex" <<'SCRIPT'
say "hello"
SCRIPT

cat > "$QUEUEBASH_ROOT/classes/WD.env" <<CLASS
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
CLASS_DEFAULT_RUNNER=direct
CLASS_DEFAULT_WORKING_DIR=$tmp/workdir
CLASS_DEFAULT_TIMEOUT=10s
queue_class_shared_asset path exists "$tmp/workdir"
CLASS

(
    cd "$tmp"
    queue submit wdjob --class WD -- rexx waiter.rex >/dev/null
)

job="$(grep -l '^JOB_NAME=wdjob$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
[[ -n "$job" ]] || fail "job not submitted"

grep -q "^PWD_AT_SUBMIT=$tmp/workdir$" "$job" || fail "class working dir did not override submit dir"
grep -q '^TIMEOUT=10s$' "$job" || fail "other class defaults missing"

qid="$(basename "$job" .job)"
explain="$(queue explain "$qid" || true)"
grep -q "working dir:[[:space:]]*$tmp/workdir" <<< "$explain" || fail "explain missing class working dir"

# Resubmit should also adopt the current class working dir.
mv "$job" "$QUEUEBASH_ROOT/failed/$qid.job"

cat > "$QUEUEBASH_ROOT/classes/WD.env" <<CLASS
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
CLASS_DEFAULT_RUNNER=direct
CLASS_DEFAULT_WORKING_DIR=$tmp/workdir/new
CLASS_DEFAULT_TIMEOUT=20s
queue_class_shared_asset path exists "$tmp/workdir"
CLASS
mkdir -p "$tmp/workdir/new"

queue resubmit "$qid" >/dev/null || fail "resubmit failed"
newjob="$(grep -l "^RESUBMITTED_FROM=$qid$" "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
[[ -n "$newjob" ]] || fail "resubmitted job not found"

grep -q "^PWD_AT_SUBMIT=$tmp/workdir/new$" "$newjob" || fail "resubmit did not adopt current class working dir"
grep -q '^TIMEOUT=20s$' "$newjob" || fail "resubmit did not adopt current timeout"

pass "class default working directory overrides submit directory"
pass "queue explain shows class working directory"
pass "resubmit adopts current class working directory"

echo
echo "bashqueues class default working directory tests: OK"
