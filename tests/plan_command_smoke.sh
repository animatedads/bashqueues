#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
trap 'rm -rf "$QUEUEBASH_ROOT"' EXIT
source ./queuebash.sh
queue plan scan fixtures/plan/kubernetes/job.yaml --json > /tmp/queue_plan_scan.json
python3 - <<'PY'
import json
obj=json.load(open('/tmp/queue_plan_scan.json'))
assert obj['schema']=='queue.plan.scan.v1', obj
assert obj['status']=='recognized', obj
assert any(x['adapter']=='kubernetes' for x in obj['detected']), obj
PY
out="$(mktemp -d)"
queue plan build fixtures/plan/kubernetes/job.yaml --output "$out" --json > /tmp/queue_plan_build.json
python3 - <<'PY'
import json
obj=json.load(open('/tmp/queue_plan_build.json'))
assert obj['schema']=='queue.plan.build.v1', obj
assert obj['status']=='ok', obj
assert obj['safe_to_apply'] is False, obj
PY
queue plan validate "$out" --json > /tmp/queue_plan_validate.json
python3 - <<'PY'
import json
obj=json.load(open('/tmp/queue_plan_validate.json'))
assert obj['schema']=='queue.plan.validate.v1', obj
assert obj['status']=='ok', obj
PY
