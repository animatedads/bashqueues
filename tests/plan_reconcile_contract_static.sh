#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
grep -q 'RECONCILE_SCHEMA = "queue.plan.reconcile.v1"' bin/queue-plan-ingest.py
grep -q 'def build_reconcile_summary' bin/queue-plan-ingest.py
grep -q 'queue plan reconcile PATH \[--json\]' queuebash.sh
grep -q 'queue plan reconcile PATH \[--json\]' resources.d/display/lang_eng/plan-help.txt
grep -q 'no SDK/API/CLI calls' docs/PLAN_RECONCILE_CONTRACT.md
grep -q 'no parallel cron scheduler' docs/PLAN_RECONCILE_CONTRACT.md
