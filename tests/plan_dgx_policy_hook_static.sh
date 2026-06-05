#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
grep -q 'DGX_CLOUD_WORKFLOW_POLICY_REVIEW' "$ROOT/bin/queue-plan-ingest.py"
grep -q 'DGX_CLOUD_WORKFLOW_POLICY_REVIEW' "$ROOT/docs/PLAN_DGX_POLICY_HOOKS.md"
grep -q 'nvidia.com/gpu' "$ROOT/fixtures/plan/kubernetes/dgx-job.yaml"
grep -q 'queue plan' "$ROOT/queuebash.sh"
echo "PASS plan_dgx_policy_hook_static"
