#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
out="$(python3 bin/queue-plan-ingest.py handoff fixtures/plan/reconcile --json)"
printf '%s\n' "$out" | grep -q '"schema":"queue.plan.handoff.v1"'
printf '%s\n' "$out" | grep -q '"safe_to_apply":false'
printf '%s\n' "$out" | grep -q '"queue plan handoff consumes supplied files only"'
printf '%s\n' "$out" | grep -q '"handoff is advisory and policy-gated; it is not apply"'
python3 - <<'PY' "$out"
import json, sys
obj=json.loads(sys.argv[1])
assert obj['schema']=='queue.plan.handoff.v1'
assert obj['handoff']['evidence_counts']['plan_definitions'] >= 1
assert obj['handoff']['evidence_counts']['runtime_job_status'] >= 1
assert obj['handoff']['reconcile_summary']['correlations'] >= 1
assert obj['handoff']['safe_to_apply'] is False
assert any(a == 'no SDK/API/CLI calls' for a in obj['attestations'])
assert obj['next_actions']
PY
