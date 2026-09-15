#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "[FAIL] $*" >&2; exit 1; }
root="$(mktemp -d)"
mockbin="$root/mockbin"
mkdir -p "$mockbin" "$root"/{pending,waiting,running,paused,done,failed,pol_blocked,interrupted,cancelled,deleted,logs,workers,outputs,streams,helpers,classes,class.d,envs.d,assets.d,caps.d,reporters.d,policies.d}
cat > "$mockbin/systemctl" <<'MOCK'
#!/usr/bin/env bash
if [[ "${1:-}" == "--user" && "${2:-}" == "show" ]]; then
  prop=""
  for arg in "$@"; do
    case "$arg" in
      -p) shift; prop="${1:-}" ;;
      ActiveState|SubState|MainPID) prop="$arg" ;;
    esac
  done
  case "$prop" in
    ActiveState) echo active ;;
    SubState) echo running ;;
    MainPID) echo "${QUEUEBASH_TEST_SYSTEMD_MAINPID:-$$}" ;;
    *) echo active ;;
  esac
  exit 0
fi
exit 1
MOCK
chmod +x "$mockbin/systemctl"
cat > "$root/running/ed209c.job" <<JOB
JOB_ID=ed209c
JOB_NAME=audio-calibration-edge
PRIORITY=10
RUNNER_USED=systemd
SYSTEMD_UNIT=queue-ed209c.service
RUN_PID=99999999
COMMAND=( bash -lc 'sleep 999' )
JOB
: > "$root/logs/ed209c.log"
export QUEUEBASH_ROOT="$root"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export PATH="$mockbin:$PATH"
export QUEUEBASH_TEST_SYSTEMD_MAINPID="$$"
# shellcheck disable=SC1091
source ./queuebash.sh
queue health --json --fix > "$root/health.json" || fail "queue health --json --fix returned non-zero"
[[ -f "$root/running/ed209c.job" ]] || fail "health --fix moved active systemd job out of running"
[[ ! -f "$root/interrupted/ed209c.job" ]] || fail "health --fix interrupted active systemd payload"
queue sentinel --once > "$root/sentinel.out" 2> "$root/sentinel.err" || fail "queue sentinel --once returned non-zero"
[[ -f "$root/running/ed209c.job" ]] || fail "sentinel moved active systemd job out of running"
[[ ! -f "$root/interrupted/ed209c.job" ]] || fail "sentinel interrupted active systemd payload"
python3 - <<PY
import json, pathlib
p=pathlib.Path('$root/health.json')
data=json.loads(p.read_text())
assert data.get('schema') == 'queuebash.health.v1', data
msgs='\n'.join(item.get('message','') for item in data.get('checks',[]))
assert 'FIX moved stale running job' not in msgs, msgs
PY
rm -rf "$root"
echo "[PASS] systemd stale-running detection trusts active SYSTEMD_UNIT/MainPID before RUN_PID fallback"
