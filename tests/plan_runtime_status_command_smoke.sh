#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
out="${TMPDIR:-/tmp}/queue_plan_status_facade.json"
QUEUEBASH_ALLOW_NONINTERACTIVE=1 bash -lc 'source ./queuebash.sh >/tmp/queue_plan_status_src.out 2>/tmp/queue_plan_status_src.err; queue plan status fixtures/plan/runtime/aws-step-functions.json --json' > "$out"
python3 - "$out" <<'PY'
import json, sys
obj=json.load(open(sys.argv[1]))
assert obj["schema"] == "queue.plan.status.v1"
assert obj["source"]["adapter"] == "aws-step-functions"
assert obj["safe_to_apply"] is False
PY
