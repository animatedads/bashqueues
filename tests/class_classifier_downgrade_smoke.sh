#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
import json, subprocess, tempfile
from pathlib import Path
root=Path.cwd()
history='tests/fixtures/class_classifier/history_normal.jsonl'
policy='tests/fixtures/class_classifier/policy_block_on_downgrade.json'
for fixture in ['jobs_downgrade.jsonl','jobs_adversarial_rename.jsonl']:
    job=json.loads((root/'tests/fixtures/class_classifier'/fixture).read_text().splitlines()[0])
    with tempfile.NamedTemporaryFile('w', suffix='.json') as f:
        json.dump(job, f); f.flush()
        obj=json.loads(subprocess.check_output(['python3','bin/queue-class-infer.py','recommend','--json','--history',history,'--policy',policy,'--job',f.name], text=True))
    assert obj['decision']=='class_downgrade_suspected', (fixture,obj)
    assert obj['recommended_action']=='block_pending_authorisation', (fixture,obj)
    assert obj['recommended_class']=='DB_EXPORT_HIGH_ASSURANCE', (fixture,obj)
    assert obj['reasons'], (fixture,obj)
print('PASS class_classifier_downgrade_smoke')
PY
