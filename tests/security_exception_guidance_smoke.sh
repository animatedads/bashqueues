#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
export QUEUEBASH_ROOT="$root"

mkdir -p "$root/classes" "$root/failed" "$root/logs"
cat > "$root/classes/DEFAULT.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
CLASS

job="$root/failed/JOBGUIDE.job"
cat > "$job" <<'JOB'
JOB_ID=JOBGUIDE
JOB_NAME=guide_wget
JOB_CLASS=DEFAULT
RUNNER=direct
RUNNER_USED=direct
COMMAND=( wget https://example.com )
SUBMITTED_AT=2026-05-25T00:00:00+00:00
RUN_STARTED_AT=2026-05-25T00:00:01+00:00
EXEC_FINISHED_AT=2026-05-25T00:00:02+00:00
EXIT_CODE=1
SANDBOX_LEVEL=strict
SANDBOX_POLICY_NAME=strict
SECCOMP_PROFILE=strict
SECCOMP_POLICY_NAME=strict
RUNTIME_CAPS='no-network-tools only-port'
RUNTIME_CAP_PORTS=443
RUNTIME_CAP_VIOLATED=1
RUNTIME_CAP_VIOLATION='no-network-tools exe=wget cmd=wget https://example.com'
LOG_PATH=logs/JOBGUIDE.log
JOB
cat > "$root/logs/JOBGUIDE.log" <<'LOG'
RUNTIME_CAP_VIOLATION: no-network-tools exe=wget cmd=wget https://example.com
LOG

out="$(bash -lc 'export QUEUEBASH_ALLOW_NONINTERACTIVE=1; source ./queuebash.sh; queue explain JOBGUIDE')"
grep -q 'Security exception guidance' <<< "$out"
grep -q -- '--drop-cap no-network-tools' <<< "$out"
grep -q 'queue submit guide_wget --class DEFAULT --drop-cap no-network-tools -- wget https://example.com' <<< "$out"

echo '[PASS] queue explain suggests the exact runtime-cap exception needed for a blocked job'
