#!/usr/bin/env bash
set -euo pipefail
out="$(python3 bin/queue-plan-ingest.py collectors fixtures/plan/runtime/collector-contracts --json)"
printf '%s
' "$out" | grep -q '"schema":"queue.plan.collectors.v1"'
printf '%s
' "$out" | grep -q 'QUEUE_PLAN_COLLECTOR_REVIEW'
printf '%s
' "$out" | grep -q 'CLOUD_WORKFLOW_POLICY_REVIEW'
printf '%s
' "$out" | grep -q 'safe_to_collect_here":false'
OUT="$out" python3 - <<'PY'
import json, os
obj=json.loads(os.environ['OUT'])
assert obj['schema']=='queue.plan.collectors.v1'
assert obj['safe_to_collect_here'] is False
adapters={c['adapter'] for c in obj['collectors']}
assert 'aws-step-functions' in adapters
assert 'windows-task-scheduler' in adapters
assert 'local-cron-status' in adapters
for c in obj['collectors']:
    assert c['safe_to_run_inside_queue_plan'] is False
print('PASS collectors json shape')
PY
echo PASS tests/plan_collector_contract_smoke.sh
