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
    grep -n '_queue_build_payload_command' -A60 "$repo_root/queuebash.sh" >&2 || true
    exit 1
}

pass(){ echo "[PASS] $1"; }

mapfile -d '' argv < <(_queue_build_payload_command "50%" "512M" "/tmp" "systemd" "30s" "5s" rexx waiter.rex)

joined=""
for x in "${argv[@]}"; do
    joined+="[$x]"
done

grep -q '\[CPUQuota=50%\]' <<< "$joined" || fail "systemd argv missing normalized CPUQuota=50%"
grep -q '\[--\]\[timeout\]\[--signal=TERM\]\[--kill-after=5s\]\[30s\]\[rexx\]\[waiter.rex\]' <<< "$joined" || fail "systemd argv missing timeout wrapper after --"

mapfile -d '' argv2 < <(_queue_build_payload_command "" "" "/tmp" "direct" "2s" "1s" bash -c 'echo ok')
joined2=""
for x in "${argv2[@]}"; do
    joined2+="[$x]"
done

grep -q '\[timeout\]\[--signal=TERM\]\[--kill-after=1s\]\[2s\]\[bash\]\[-c\]\[echo ok\]' <<< "$joined2" || fail "direct/setsid argv missing timeout wrapper"

if ! grep -q 'timeout_request:' "$repo_root/queuebash.sh"; then
    fail "runner log does not mention timeout_request"
fi

pass "systemd payload argv includes timeout wrapper"
pass "direct payload argv includes timeout wrapper"
pass "CPUQuota and timeout wrapper coexist"

echo
echo "bashqueues timeout enforcement tests: OK"
