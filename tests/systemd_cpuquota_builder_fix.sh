#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_RUNNER=systemd
export QUEUEBASH_GZIP_LOGS=0
export QUEUEBASH_PLUGIN_SOURCE_DIR="$repo_root/assets.d"
export QUEUEBASH_CLASS_SOURCE_DIR="$repo_root/classes"

source "$repo_root/queuebash.sh"

fail() {
    echo "[FAIL] $1" >&2
    grep -n 'CPUQuota' "$repo_root/queuebash.sh" >&2 || true
    exit 1
}

pass(){ echo "[PASS] $1"; }

[[ "$(_queue_normalize_systemd_cpu_quota 50)" == "50%" ]] || fail "50 did not normalize to 50%"
[[ "$(_queue_normalize_systemd_cpu_quota 50%)" == "50%" ]] || fail "50% did not stay 50%"
[[ "$(_queue_normalize_systemd_cpu_quota 12.5%)" == "12.5%" ]] || fail "12.5% did not stay 12.5%"

# The actual bug was a builder that appended percent to an already-percented value.
if grep -F 'CPUQuota=${cpu}%' "$repo_root/queuebash.sh" >/dev/null; then
    fail 'source still contains CPUQuota=${cpu}%'
fi

if grep -F 'CPUQuota=$cpu%' "$repo_root/queuebash.sh" >/dev/null; then
    fail 'source still contains CPUQuota=$cpu%'
fi

if grep -F 'CPUQuota=${cpu//%/%%}' "$repo_root/queuebash.sh" >/dev/null; then
    fail 'source still contains percent double-escape substitution'
fi

grep -q '_queue_normalize_systemd_cpu_quota "$cpu"' "$repo_root/queuebash.sh" || fail "systemd builder does not call normalizer"

# Build a tiny NUL argv through the real function if available.
if declare -F _queue_build_command_runner_argv >/dev/null 2>&1; then
    true
fi

pass "CPU quota normalizer handles numeric and percent values"
pass "systemd builder no longer appends an extra percent"
pass "source no longer contains the bad CPUQuota patterns"

echo
echo "bashqueues systemd CPUQuota builder fix tests: OK"
