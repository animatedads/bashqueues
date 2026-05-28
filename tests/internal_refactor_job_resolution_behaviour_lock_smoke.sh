#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail(){ echo "FAIL: $*" >&2; exit 1; }

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
trap 'rm -rf "$QUEUEBASH_ROOT"' EXIT

source ./queuebash.sh

# This behaviour-lock test exercises job operand resolution, not bundled
# installation. Avoid repeatedly walking bundled assets/policies on every queue
# command in the temporary root; installer coverage is locked separately.
_queue_install_bundled_classes(){ :; }
_queue_install_bundled_env_profiles(){ :; }
_queue_install_bundled_asset_plugins(){ :; }
_queue_install_bundled_cap_plugins(){ :; }
_queue_install_bundled_reporter_plugins(){ :; }
_queue_install_bundled_policies(){ :; }
_queue_init(){ :; }

mkdir -p "$QUEUEBASH_ROOT"/{pending,running,paused,done,failed,pol_blocked,interrupted,cancelled,deleted,logs,events,workers,clearance}

make_job(){
  local state="$1" id="$2" name="$3"
  mkdir -p "$QUEUEBASH_ROOT/$state"
  cat > "$QUEUEBASH_ROOT/$state/$id.job" <<JOB
JOB_NAME=$name
CLASS=DEFAULT
RUNNER=auto
RUNNER_USED=direct
PWD_AT_SUBMIT=/tmp
SUBMITTED_AT=2026-05-28T00:00:00+00:00
COMMAND=( bash -lc true )
PRIORITY=10
ON_SUCCESS=()
ON_FAILURE=()
EXIT_CODE=0
DURATION_SECONDS=0
LOG_BYTES=0
JOB
  printf 'log for %s\n' "$id" > "$QUEUEBASH_ROOT/logs/$id.log"
}

capture(){
  local var="$1"; shift
  local rc=0 captured
  set +e
  captured=$("$@" 2>&1)
  rc=$?
  set -e
  printf -v "$var" '%s' "$captured"
  return "$rc"
}

expect_rc(){
  local expected="$1" var="$2"; shift 2
  local rc=0
  capture "$var" "$@" || rc=$?
  [[ "$rc" -eq "$expected" ]] || {
    printf 'Expected rc %s got %s for:' "$expected" "$rc" >&2
    printf ' %q' "$@" >&2
    printf '\nOutput:\n%s\n' "${!var}" >&2
    exit 1
  }
}

assert_contains(){
  local hay="$1" needle="$2" label="$3"
  grep -Fq -- "$needle" <<< "$hay" || fail "$label: expected [$needle] in output: $hay"
}

# Controlled job set.  The IDs deliberately create unique and ambiguous prefixes.
make_job done    20260528_111111_000000001_000001_1000001 shared_name
make_job done    20260528_111111_000000002_000002_1000002 shared_name
make_job done    20260528_222222_000000003_000003_2000003 single_name
make_job done    20260528_333333_000000004_000004_3000004 alpha_name
make_job done    20260528_333333_000000005_000005_3000005 beta_name
make_job failed  20260528_444444_000000006_000006_4000006 retry_name
make_job failed  20260528_444444_000000007_000007_4000007 retry_name
make_job paused  20260528_555555_000000008_000008_5000008 paused_name
make_job paused  20260528_555555_000000009_000009_5000009 paused_name
make_job deleted 20260528_666666_000000010_000010_6000010 deleted_name
make_job deleted 20260528_666666_000000011_000011_6000011 deleted_name

# exact QID: exact QID wins and read-only command succeeds for one job.
expect_rc 0 out queue show 20260528_222222_000000003_000003_2000003 --tail 1
assert_contains "$out" 'JOB: 20260528_222222_000000003_000003_2000003' 'exact QID show'
assert_contains "$out" 'Shown 1 job(s)' 'exact QID show count'

# unique prefix: unique QID prefix is accepted by read-only commands.
expect_rc 0 out queue show 20260528_222222 --tail 1
assert_contains "$out" 'JOB: 20260528_222222_000000003_000003_2000003' 'unique prefix show'
assert_contains "$out" 'Shown 1 job(s)' 'unique prefix show count'

# exact name group: read-only group allowed commands accept exact job names.
expect_rc 0 out queue show shared_name --tail 1
assert_contains "$out" 'Shown 2 job(s)' 'exact name group show'

# single job required: metrics refuses exact-name groups.
expect_rc 2 out queue metrics shared_name
assert_contains "$out" "multiple jobs named 'shared_name'; use a QID" 'single job required exact name group refused'

# ambiguous prefix: read-only and mutating commands diagnose ambiguous QID prefixes.
expect_rc 2 out queue show 20260528_333333
assert_contains "$out" 'queue show: ambiguous QID prefix: 20260528_333333' 'ambiguous prefix show refused'
expect_rc 2 out queue cancel 20260528_333333 --dryrun
assert_contains "$out" 'queue cancel: ambiguous QID prefix: 20260528_333333' 'ambiguous prefix cancel refused'
assert_contains "$out" 'Use a fuller QID or --force' 'ambiguous prefix cancel force diagnostic'

# --force: force-sensitive mutating commands keep existing broad-prefix behaviour.
expect_rc 0 out queue cancel 20260528_333333 --dryrun --force
assert_contains "$out" 'DRYRUN: would move 20260528_333333_000000004_000004_3000004' 'force cancel first'
assert_contains "$out" 'DRYRUN: would move 20260528_333333_000000005_000005_3000005' 'force cancel second'

# mutating exact-name groups: dryrun mutators accept exact names with multiple matches.
expect_rc 0 out queue priority shared_name 42 --dryrun
assert_contains "$out" 'DRYRUN: would set priority for 20260528_111111_000000001_000001_1000001 to 42' 'priority exact name group first'
assert_contains "$out" 'Updated 2 job(s)' 'priority exact name group count'
expect_rc 0 out queue onsuccess shared_name --dryrun -- echo ok
assert_contains "$out" 'DRYRUN: would set ON_SUCCESS' 'onsuccess exact name group'
assert_contains "$out" 'DRYRUN: would update 2 job(s)' 'onsuccess exact name group count'

# paused state scope: unpause searches only paused jobs and accepts exact-name groups.
expect_rc 0 out queue unpause paused_name --dryrun
assert_contains "$out" 'DRYRUN: would unpause 20260528_555555_000000008_000008_5000008 -> pending' 'paused state scope exact name first'
expect_rc 2 out queue unpause 20260528_555555 --dryrun
assert_contains "$out" 'queue unpause: ambiguous QID prefix: 20260528_555555' 'paused state scope ambiguous prefix'

# deleted state scope: undelete searches only deleted jobs and force controls ambiguous prefixes.
expect_rc 0 out queue undelete deleted_name --dryrun
assert_contains "$out" 'DRYRUN: would restore 20260528_666666_000000010_000010_6000010 to pending' 'deleted state scope exact name first'
expect_rc 2 out queue undelete 20260528_666666 --dryrun
assert_contains "$out" 'queue undelete: ambiguous QID prefix: 20260528_666666' 'deleted state scope ambiguous prefix'
assert_contains "$out" 'Use a fuller QID or --force' 'deleted state scope force diagnostic'
expect_rc 0 out queue undelete 20260528_666666 --dryrun --force
assert_contains "$out" 'DRYRUN: would restore 20260528_666666_000000010_000010_6000010 to pending' 'deleted state scope force first'

# retry state-filtered clone: retry/resubmit only eligible states and preserves force semantics.
expect_rc 0 out queue retry retry_name --dryrun
assert_contains "$out" 'DRYRUN: would resubmit 2 failed/interrupted/pol_blocked job(s).' 'retry state-filtered clone exact name group'
expect_rc 2 out queue retry 20260528_444444 --dryrun
assert_contains "$out" 'queue resubmit: ambiguous QID prefix: 20260528_444444' 'retry state-filtered clone ambiguous prefix'
assert_contains "$out" 'Use a fuller QID or --force' 'retry state-filtered clone force diagnostic'
expect_rc 0 out queue retry 20260528_444444 --dryrun --force
assert_contains "$out" 'DRYRUN: would resubmit 2 failed/interrupted/pol_blocked job(s).' 'retry state-filtered clone force'

echo "PASS internal_refactor_job_resolution_behaviour_lock_smoke"
