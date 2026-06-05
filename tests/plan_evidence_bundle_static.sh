#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "FAIL $*" >&2; exit 1; }

grep -q 'EVIDENCE_SCHEMA = "queue.plan.evidence.v1"' bin/queue-plan-ingest.py || fail 'missing evidence schema'
grep -q 'def build_evidence_summary' bin/queue-plan-ingest.py || fail 'missing evidence summary function'
grep -q 'queue plan evidence PATH \[--json\]' queuebash.sh || fail 'missing queuebash evidence usage comment'
grep -q 'scan|explain|policy|status|sources|evidence|build|validate' queuebash.sh || fail 'queuebash facade does not dispatch evidence'
grep -q 'queue plan evidence PATH \[--json\]' resources.d/display/lang_eng/plan-help.txt || fail 'lang_eng help missing evidence command'
grep -q 'queue.plan.evidence.v1' docs/PLAN_EVIDENCE_BUNDLE_CONTRACT.md || fail 'doc missing schema'
grep -q 'no parallel cron scheduler' docs/PLAN_EVIDENCE_BUNDLE_CONTRACT.md || fail 'doc missing cron boundary'

echo PASS plan_evidence_bundle_static
