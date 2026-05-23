#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1 QUEUEBASH_RUNNER=direct QUEUEBASH_GZIP_LOGS=0 QUEUEBASH_PLUGIN_SOURCE_DIR="$repo_root/assets.d"
source "$repo_root/queuebash.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"; _queue_init
fail(){ echo "[FAIL] $1" >&2; queue assets >&2 || true; queue assets validate >&2 || true; find "$QUEUEBASH_ROOT" -maxdepth 5 -print >&2 || true; exit 1; }
pass(){ echo "[PASS] $1"; }
[[ -f "$QUEUEBASH_ROOT/assets.d/git.sh" ]] || fail "git.sh not installed"
[[ -f "$QUEUEBASH_ROOT/assets.d/db.sh" ]] || fail "db.sh not installed"
queue assets validate >/dev/null || fail "bundled plugins invalid"
out="$(queue assets)"
grep -q '^git:repo_exists' <<< "$out" || fail "git:repo_exists missing"
grep -q '^git:clean_tree' <<< "$out" || fail "git:clean_tree missing"
grep -q '^git:branch' <<< "$out" || fail "git:branch missing"
grep -q '^db:sqlite_accessible' <<< "$out" || fail "db:sqlite_accessible missing"
grep -q '^db:postgres_connect' <<< "$out" || fail "db:postgres_connect missing"
repo="$tmp/repo"; mkdir -p "$repo"
git -C "$repo" init >/dev/null 2>&1 || fail "git init failed"
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name Test
echo hello > "$repo/file.txt"; git -C "$repo" add file.txt; git -C "$repo" commit -m init >/dev/null 2>&1 || fail "git commit failed"
branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD)"
cat > "$QUEUEBASH_ROOT/classes/GIT_OK.env" <<CLASS
CLASS_ALLOW_PARALLEL=1
CLASS_SHARED_ASSETS="git:repo_exists:$repo git:clean_tree:$repo git:branch:$repo:require_branch=$branch"
CLASS
queue submit git_ok --class GIT_OK -- bash -c 'echo git-ok' >/dev/null
job="$(grep -l '^JOB_NAME=git_ok$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
_queue_class_available "$job" || fail "git_ok should dispatch"
if command -v sqlite3 >/dev/null 2>&1; then
 db="$tmp/test.db"; sqlite3 "$db" 'CREATE TABLE t(x); INSERT INTO t VALUES (1);'
 cat > "$QUEUEBASH_ROOT/classes/SQLITE_OK.env" <<CLASS
CLASS_ALLOW_PARALLEL=1
CLASS_SHARED_ASSETS="db:sqlite_accessible:$db:query=SELECT 1"
CLASS
 queue submit sqlite_ok --class SQLITE_OK -- bash -c 'echo sqlite-ok' >/dev/null
 sjob="$(grep -l '^JOB_NAME=sqlite_ok$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
 _queue_class_available "$sjob" || fail "sqlite_ok should dispatch"
fi
queue assets expand | grep -q 'asset subcommands:' || fail "expand missing subcommands"
queue assets expand | grep -q 'git' || fail "expand missing git"
pass "git and db plugins install externally"
pass "git and db plugins publish valid contracts"
pass "deterministic git/sqlite checks dispatch"
pass "assets expand lists subcommands and families"
echo
echo "bashqueues git/db asset plugin tests: OK"
