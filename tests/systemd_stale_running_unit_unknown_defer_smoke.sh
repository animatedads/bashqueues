#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "[FAIL] $*" >&2; exit 1; }
root="$(mktemp -d)"
mockbin="$root/mockbin"
mkdir -p "$mockbin" "$root"/{pending,waiting,running,paused,done,failed,pol_blocked,interrupted,cancelled,deleted,logs,workers,outputs,streams,helpers,classes,class.d,envs.d,assets.d,caps.d,reporters.d,policies.d}
cat > "$mockbin/systemctl" <<'MOCK'
#!/usr/bin/env bash
# Simulate the installed sentinel/manager being unable to query the user unit.
exit 1
MOCK
chmod +x "$mockbin/systemctl"
cat > "$root/running/ed209b.job" <<JOB
JOB_ID=ed209b
JOB_NAME=audio-calibration-edge
PRIORITY=10
RUNNER_USED=systemd
SYSTEMD_UNIT=queue-ed209b.service
RUN_PID=99999999
COMMAND=( bash -lc 'sleep 999' )
JOB
: > "$root/logs/ed209b.log"
export QUEUEBASH_ROOT="$root"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export PATH="$mockbin:$PATH"
# shellcheck disable=SC1091
source ./queuebash.sh
queue health --json --fix > "$root/health.json" || fail "queue health --json --fix returned non-zero"
[[ -f "$root/running/ed209b.job" ]] || fail "health --fix moved unqueryable systemd unit out of running"
[[ ! -f "$root/interrupted/ed209b.job" ]] || fail "health --fix interrupted a recorded systemd unit by stale RUN_PID fallback"
queue sentinel --once > "$root/sentinel.out" 2> "$root/sentinel.err" || fail "queue sentinel --once returned non-zero"
[[ -f "$root/running/ed209b.job" ]] || fail "sentinel moved unqueryable systemd unit out of running"
[[ ! -f "$root/interrupted/ed209b.job" ]] || fail "sentinel interrupted recorded systemd unit by stale RUN_PID fallback"
rm -rf "$root"
echo "[PASS] recorded systemd units defer on unknown systemctl state instead of using dead launcher RUN_PID"
