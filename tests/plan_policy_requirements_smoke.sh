#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
python3 bin/queue-plan-ingest.py policy fixtures/plan/kubernetes/dgx-job.yaml --json > /tmp/queue_plan_policy.json
python3 - <<'PY'
import json
obj=json.load(open('/tmp/queue_plan_policy.json'))
assert obj['schema']=='queue.plan.policy.v1', obj
reqs=obj['policy_requirements']
assert any(r['name']=='DGX_CLOUD_WORKFLOW_POLICY_REVIEW' for r in reqs), reqs
dgx=next(r for r in reqs if r['name']=='DGX_CLOUD_WORKFLOW_POLICY_REVIEW')
assert dgx['policy_family']=='gpu-cloud', dgx
assert 'lifecycle' in dgx['applies_to'], dgx
assert any(p.startswith('policies.d/gpu-cloud/') for p in dgx['policy_files']), dgx
assert obj['safe_to_apply'] is False, obj
PY
echo "PASS plan_policy_requirements_smoke"
