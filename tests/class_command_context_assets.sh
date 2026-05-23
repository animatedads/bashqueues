#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_RUNNER=direct
export QUEUEBASH_GZIP_LOGS=0
export QUEUEBASH_PLUGIN_SOURCE_DIR="$repo_root/assets.d"
unset QUEUEBASH_CLASS_SOURCE_DIR

source "$repo_root/queuebash.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
_queue_init

fail() {
    echo "[FAIL] $1" >&2
    echo "--- class ---" >&2
    cat "$QUEUEBASH_ROOT/classes/CMDCTX.env" >&2 || true
    echo "--- pending job ---" >&2
    cat "$QUEUEBASH_ROOT"/pending/*.job >&2 || true
    echo "--- context ---" >&2
    job="$(ls "$QUEUEBASH_ROOT"/pending/*.job 2>/dev/null | head -1 || true)"
    [[ -n "$job" ]] && _queue_class_export_job_context "$job" >&2 || true
    echo "--- preflight ---" >&2
    cat /tmp/cmdctx.out >&2 || true
    exit 1
}

pass(){ echo "[PASS] $1"; }

mkdir -p "$tmp/work"
cat > "$tmp/work/manwell.rex" <<'REXX'
say "manwell"
REXX

cat > "$QUEUEBASH_ROOT/assets.d/probe.sh" <<'PLUGIN'
queue_asset_facilities() {
    echo "probe:path Checks target path"
}

queue_asset_check_probe_path() {
    local target="${1:-}"
    shift || true
    [[ -n "$target" ]] || { echo "asset_check_blocked: probe:path no target"; return 1; }
    [[ "$target" == */manwell.rex ]] || { echo "asset_check_blocked: probe:path wrong_target=$target"; return 2; }
    [[ -f "$target" ]] || { echo "asset_check_blocked: probe:path missing target=$target"; return 3; }
    echo "asset_check_ok: probe:path target=$target args=$*"
}
PLUGIN

queue assets validate probe >/dev/null || fail "probe helper did not validate"

cat > "$QUEUEBASH_ROOT/classes/CMDCTX.env" <<CLASS
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
CLASS_DEFAULT_RUNNER=direct
CLASS_DEFAULT_WORKING_DIR=$tmp/work
queue_class_shared_asset probe path "\${QUEUEBASH_COMMAND_ARG_1_ABSPATH:-$tmp/work/fallback.rex}" mode=cmdctx
CLASS

(
    cd "$tmp"
    queue submit cmdctx --class CMDCTX -- rexx manwell.rex >/dev/null
)

job="$(grep -l '^JOB_NAME=cmdctx$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
[[ -n "$job" ]] || fail "job not submitted"

grep -q "^PWD_AT_SUBMIT=$tmp/work$" "$job" || fail "class default working dir not applied"

_queue_class_export_job_context "$job" >/tmp/context.out
grep -q "^QUEUEBASH_COMMAND_ARG_1_ABSPATH=$tmp/work/manwell\\.rex$" /tmp/context.out || fail "command arg absolute path context wrong"

(
    _queue_class_load_for_job "$job" >/dev/null
    _queue_asset_implied_preflight_for_class
) >/tmp/cmdctx.out || fail "command-context preflight failed"

grep -q "asset_check_ok: probe:path target=$tmp/work/manwell.rex args=mode=cmdctx" /tmp/cmdctx.out || fail "class asset did not receive command arg absolute path"

pass "class preflight exports command argument context"
pass "record assets can use submitted command target"
pass "class default working dir and command target combine correctly"

echo
echo "bashqueues class command-context asset tests: OK"
