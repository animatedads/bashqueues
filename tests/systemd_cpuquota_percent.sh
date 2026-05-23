#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_RUNNER=systemd
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
    find "$QUEUEBASH_ROOT" -maxdepth 5 -type f -print -exec sh -c 'echo "### $1"; sed -n "1,180p" "$1"' _ {} \; >&2 || true
    exit 1
}

pass(){ echo "[PASS] $1"; }

[[ "$(_queue_normalize_systemd_cpu_quota 50)" == "50%" ]] || fail "numeric CPU quota did not gain percent"
[[ "$(_queue_normalize_systemd_cpu_quota 50%)" == "50%" ]] || fail "percent CPU quota was changed"
[[ "$(_queue_normalize_systemd_cpu_quota 12.5%)" == "12.5%" ]] || fail "decimal percent CPU quota was changed"

cat > "$QUEUEBASH_ROOT/classes/CPUQ.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
CLASS_DEFAULT_RUNNER=systemd
CLASS_DEFAULT_CPU_LIMIT=50%
CLASS_DEFAULT_MEM_LIMIT=512M
queue_class_shared_asset path exists "/tmp"
CLASS

queue submit cpuq --class CPUQ -- bash -c 'echo cpuq' >/dev/null
job="$(grep -l '^JOB_NAME=cpuq$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
[[ -n "$job" ]] || fail "cpuq job not submitted"
qid="$(basename "$job" .job)"

grep -q '^CPU_LIMIT=50%$' "$job" || fail "job record missing CPU_LIMIT=50%"

# Exercise launch argv construction without needing systemd to be available in CI:
# dryrun should render the argv/log plan in this tree if supported. If not,
# static source check below still protects against the original regression.
if queue dryrun "$qid" >/tmp/cpuq.dryrun 2>&1; then
    if grep -q 'CPUQuota=50%%' /tmp/cpuq.dryrun; then
        fail "dryrun contains invalid CPUQuota=50%%"
    fi
fi

if grep -R 'CPUQuota=.*//%/%%' "$repo_root/queuebash.sh" >/dev/null; then
    fail "source still double-escapes CPUQuota percent"
fi

if grep -R 'CPUQuota=50%%' "$repo_root/queuebash.sh" >/dev/null; then
    fail "source contains literal invalid CPUQuota=50%%"
fi

pass "CPU quota normalizer preserves one literal percent"
pass "class default CPU_LIMIT=50% is recorded"
pass "source no longer double-escapes CPUQuota"

echo
echo "bashqueues systemd CPUQuota percent tests: OK"
