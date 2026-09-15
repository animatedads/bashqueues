#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
out="$(python3 bin/queue-plan-ingest.py reconcile fixtures/plan/reconcile --json)"
printf '%s\n' "$out" | grep -q '"schema":"queue.plan.reconcile.v1"'
printf '%s\n' "$out" | grep -q '"safe_to_apply":false'
printf '%s\n' "$out" | grep -q '"correlation_is_advisory":true'
printf '%s\n' "$out" | grep -q '"orphan_runtime_job_status"'
python3 - <<'PY' "$out"
import json, sys
obj=json.loads(sys.argv[1])
assert obj['schema']=='queue.plan.reconcile.v1'
assert obj['summary']['runtime_job_status'] >= 1
assert obj['summary']['plan_definitions'] >= 1
assert obj['summary']['correlations'] >= 1
assert obj['review']['safe_to_apply'] is False
assert any('no SDK/API/CLI calls' == a for a in obj['attestations'])
PY
