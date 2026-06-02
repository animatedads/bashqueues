#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

[[ -f bin/queue-dev-merge-plan.py ]] || fail 'merge-plan helper missing'
[[ -x bin/queue-dev-merge-plan.py ]] || fail 'merge-plan helper not executable'
[[ -f docs/QUEUE_DEV_MERGE_PLAN.md ]] || fail 'merge-plan docs missing'

grep -q 'queue dev merge-plan' queuebash.sh || fail 'queue dev usage missing merge-plan'
grep -q '_queue_dev_merge_plan_command' queuebash.sh || fail 'merge-plan wrapper missing'
grep -q 'queuebash.dev_merge_plan.v1' bin/queue-dev-merge-plan.py || fail 'schema missing'
grep -q 'bounded' docs/QUEUE_DEV_MERGE_PLAN.md || fail 'bounded extraction docs missing'
grep -q 'ledger_overlap_not_runtime_conflict' docs/QUEUE_DEV_MERGE_PLAN.md || fail 'version overlap policy docs missing'
grep -q 'static_fallback_used' bin/queue-dev-merge-plan.py || fail 'static fallback marker missing'
grep -qi 'item-level' docs/QUEUE_DEV_MERGE_PLAN.md || fail 'scratchpad item-level docs missing'
grep -q 'No automatic conflict resolution' docs/QUEUE_DEV_MERGE_PLAN.md || fail 'non-goals missing'

if grep -q 'extractall' bin/queue-dev-merge-plan.py; then
  fail 'merge-plan helper must not use zip extractall in v1'
fi

python3 -m py_compile bin/queue-dev-merge-plan.py

echo 'PASS dev_merge_plan_static'
