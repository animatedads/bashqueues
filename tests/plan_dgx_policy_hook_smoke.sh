#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
python3 bin/queue-plan-ingest.py explain fixtures/plan/kubernetes/dgx-job.yaml --json > /tmp/queue_plan_dgx.json
python3 - <<'PY'
import json
obj=json.load(open('/tmp/queue_plan_dgx.json'))
gates=obj['plan']['approval_gates']
assert any(g['name']=='DGX_CLOUD_WORKFLOW_POLICY_REVIEW' for g in gates), gates
reqs=obj['plan'].get('policy_requirements', [])
assert any(r['name']=='DGX_CLOUD_WORKFLOW_POLICY_REVIEW' and r['policy_family']=='gpu-cloud' for r in reqs), reqs
assert any(c['name']=='DGX_GPU_WORKFLOW' for c in obj['plan']['classes']), obj['plan']['classes']
assert obj['analysis']['safe_to_apply'] is False, obj['analysis']
PY
echo "PASS plan_dgx_policy_hook_smoke"
