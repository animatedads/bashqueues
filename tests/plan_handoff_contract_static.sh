#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
grep -q 'HANDOFF_SCHEMA = "queue.plan.handoff.v1"' bin/queue-plan-ingest.py
grep -q 'def build_handoff_summary' bin/queue-plan-ingest.py
grep -q 'queue plan handoff PATH \[--json\]' queuebash.sh
grep -q 'queue plan handoff PATH \[--json\]' resources.d/display/lang_eng/plan-help.txt
grep -q 'queue.plan.handoff.v1' docs/PLAN_HANDOFF_CONTRACT.md
grep -q 'no SDK/API/CLI' docs/PLAN_HANDOFF_CONTRACT.md
grep -q 'no parallel cron scheduler' docs/PLAN_HANDOFF_CONTRACT.md
