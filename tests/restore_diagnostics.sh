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

fail() {
    echo "[FAIL] $1" >&2
    queue list >&2 || true
    find "$QUEUEBASH_ROOT" -type f -name '*.job' -print -exec cat {} \; >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

queue submit publish_to_git -- bash -c 'echo ok' >/dev/null
queue run >/dev/null || true

if queue restore publish_to_git >"$tmp/out" 2>"$tmp/err"; then
    fail "restore unexpectedly succeeded for non-deleted job"
fi

grep -q 'no matching deleted job: publish_to_git' "$tmp/err" || fail "missing no deleted message"
grep -q 'exist outside deleted' "$tmp/err" || fail "missing outside deleted diagnostic"
grep -q 'done' "$tmp/err" || fail "missing actual state diagnostic"
grep -q 'publish_to_git' "$tmp/err" || fail "missing job name in diagnostic"

queue delete publish_to_git >/dev/null
queue restore publish_to_git >/dev/null

queue list --state pending --name publish_to_git > "$tmp/list.txt"
grep -q 'publish_to_git' "$tmp/list.txt" || fail "deleted job was not restored to pending"

pass "restore reports matching non-deleted jobs"
pass "restore still restores deleted jobs"

echo
echo "bashqueues restore diagnostics tests: OK"
