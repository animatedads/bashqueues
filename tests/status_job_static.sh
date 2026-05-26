#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

for needle in \
  '_queue_status_job()' \
  'status|stat)' \
  'queue status <qid-or-exact-job-name> [--json] [--tail N]' \
  '"submission_line"' \
  '"command_line"' \
  '"pids"' \
  '"tail"'; do
  grep -Fq "$needle" queuebash.sh || fail "missing queue status wiring: $needle"
done

# Canonical policy-block state is pol_blocked.  The older policy_blocked
# directory may still be scanned for compatibility, but must not be advertised.
grep -Fq 'pol_blocked' queuebash.sh || fail "missing canonical pol_blocked state"
! grep -Fq 'pol_block|policy_blocked' < <(grep -E 'queue list \[--state|COMPREPLY=.*pending running|printf .*pending running' queuebash.sh) || \
  fail "user-facing state lists still advertise old policy block names"

echo "[PASS] queue status command and canonical pol_blocked state are wired"
