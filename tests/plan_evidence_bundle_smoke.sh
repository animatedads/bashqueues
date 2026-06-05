#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
json="$(${QUEUEBASH_PYTHON:-python3} bin/queue-plan-ingest.py evidence fixtures/plan/runtime --json)"
python3 - "$json" <<'PY'
import json, sys
obj=json.loads(sys.argv[1])
assert obj['schema']=='queue.plan.evidence.v1'
assert obj['status']=='ok'
counts=obj['evidence']['counts']
assert counts['runtime_job_status'] >= 1, counts
assert counts['source_contracts'] >= 1, counts
assert obj['review']['safe_to_apply'] is False
att='\n'.join(obj['attestations'])
assert 'no SDK/API/CLI calls' in att
assert 'no parallel cron scheduler' in att
print('PASS plan_evidence_bundle_smoke')
PY
