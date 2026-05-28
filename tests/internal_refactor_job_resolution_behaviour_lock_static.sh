#!/usr/bin/env bash
set -euo pipefail

fail(){ echo "FAIL: $*" >&2; exit 1; }

[[ -f queuebash.sh ]] || fail "run from repository root"
[[ -f docs/JOB_RESOLUTION_INVENTORY.md ]] || fail "missing job resolution inventory doc"
[[ -f tests/internal_refactor_job_resolution_behaviour_lock_smoke.sh ]] || fail "missing behaviour lock smoke test"

grep -q 'QUEUEBASH_VERSION="0.18.22"' queuebash.sh || fail 'version not bumped to 0.18.22'
grep -q 'WIZARD_VERSION="0.18.22"' bin/queue-policy-wizard || fail 'wizard version not bumped to 0.18.22'

# Behaviour-lock release: the future helper must still not be implemented.
if grep -q '^_queue_resolve_job_operand()' queuebash.sh; then
  fail "behaviour-lock release must not implement _queue_resolve_job_operand yet"
fi

doc="docs/JOB_RESOLUTION_INVENTORY.md"
grep -q '_queue_resolve_job_operand TARGET MODE' "$doc" || fail "inventory doc missing future helper sketch"
grep -q 'does not extract helpers and does not change command behaviour' "$doc" || fail "inventory doc must still describe no behaviour change"

smoke="tests/internal_refactor_job_resolution_behaviour_lock_smoke.sh"
for token in \
  'exact QID' \
  'unique prefix' \
  'ambiguous prefix' \
  'exact name group' \
  '--force' \
  'paused state scope' \
  'deleted state scope' \
  'retry state-filtered clone'; do
  grep -Fq -- "$token" "$smoke" || fail "smoke test missing coverage marker: $token"
done

# The smoke test should assert current UX diagnostics, not just pass/fail status.
for diag in \
  'ambiguous QID prefix' \
  'multiple jobs named' \
  'Use a fuller QID or --force' \
  'DRYRUN: would' \
  'Shown 2 job(s)' \
  'Updated 2 job(s)' \
  'would restore'; do
  grep -Fq -- "$diag" "$smoke" || fail "smoke test missing diagnostic assertion: $diag"
done

echo "PASS internal_refactor_job_resolution_behaviour_lock_static"
