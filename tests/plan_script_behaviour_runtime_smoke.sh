#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python3 bin/queue-plan-ingest.py scan fixtures/plan/script/backup-and-upload.sh --json > /tmp/queue_plan_script_backup.json
python3 - <<'PY'
import json
obj=json.load(open('/tmp/queue_plan_script_backup.json'))
assert obj['schema']=='queue.plan.scan.v1', obj
assert obj['status']=='recognized', obj
assert obj['source']['adapter']=='script-behaviour', obj['source']
det=obj['detected'][0]
assert det['script_behaviour']['schema']=='queue.plan.script_behaviour.v1', det
assert 'BACKUP_JOB' in det['script_behaviour']['classes'], det['script_behaviour']
assert any(a['type']=='database' for a in det['script_behaviour']['assets']), det['script_behaviour']['assets']
assert any(a['type']=='object_storage' for a in det['script_behaviour']['assets']), det['script_behaviour']['assets']
assert any(i['type']=='cloud_identity' for i in det['script_behaviour']['identities']), det['script_behaviour']['identities']
assert any(s['type']=='database_credential_reference' for s in det['script_behaviour']['secrets']), det['script_behaviour']['secrets']
assert any(n['reason']=='script_static_review_required' for n in det['needs_review']), det['needs_review']
assert obj['analysis']['safe_to_apply'] is False, obj['analysis']
PY

python3 bin/queue-plan-ingest.py scan fixtures/plan/script/unsafe-curl-pipe.sh --json > /tmp/queue_plan_script_unsafe.json
python3 - <<'PY'
import json
obj=json.load(open('/tmp/queue_plan_script_unsafe.json'))
det=obj['detected'][0]
assert det['adapter']=='script-behaviour', det
assert any(u['reason']=='curl_pipe_to_shell' for u in det['unsafe_refused']), det['unsafe_refused']
assert any(n['reason']=='host_service_mutation' for n in det['needs_review']), det['needs_review']
assert obj['analysis']['safe_to_stage'] is False, obj['analysis']
assert obj['analysis']['safe_to_apply'] is False, obj['analysis']
PY

echo "PASS plan_script_behaviour_runtime_smoke"
