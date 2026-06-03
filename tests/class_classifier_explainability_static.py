#!/usr/bin/env python3
import json
import subprocess
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
job = json.loads((root/'tests/fixtures/class_classifier/jobs_downgrade.jsonl').read_text().splitlines()[0])
with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.json') as tmp:
    json.dump(job, tmp)
    tmp.flush()
    out = subprocess.check_output([
        'python3', str(root/'bin/queue-class-infer.py'), 'explain', '--json',
        '--history', str(root/'tests/fixtures/class_classifier/history_normal.jsonl'),
        '--policy', str(root/'tests/fixtures/class_classifier/policy_block_on_downgrade.json'),
        '--job', tmp.name,
    ], cwd=root, text=True)
obj = json.loads(out)
assert obj['schema'] == 'queuebash.class_inference.explain.v1'
rec = obj['recommendation']
assert rec['decision'] == 'class_downgrade_suspected', rec
assert rec['recommended_action'] == 'block_pending_authorisation', rec
assert rec['reasons'], rec
text = obj['explain_text']
for needle in ['requested:', 'recommended:', 'confidence:', 'reasons:']:
    assert needle in text, text
print('PASS class_classifier_explainability_static')
