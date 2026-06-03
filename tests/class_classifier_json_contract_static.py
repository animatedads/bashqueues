#!/usr/bin/env python3
import json
import subprocess
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
helper = root / 'bin/queue-class-infer.py'
fixtures = root / 'tests/fixtures/class_classifier'
history = fixtures / 'history_normal.jsonl'
policy = fixtures / 'policy_block_on_downgrade.json'

case_files = [
    'jobs_normal.jsonl',
    'jobs_downgrade.jsonl',
    'jobs_near_miss.jsonl',
    'jobs_cold_start.jsonl',
    'jobs_adversarial_rename.jsonl',
    'jobs_drift.jsonl',
]

def run_job(job):
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.json') as tmp:
        json.dump(job, tmp)
        tmp.flush()
        out = subprocess.check_output([
            'python3', str(helper), 'recommend', '--json',
            '--history', str(history), '--policy', str(policy), '--job', tmp.name,
        ], cwd=root, text=True)
    return json.loads(out)

seen = 0
for name in case_files:
    for line in (fixtures / name).read_text(encoding='utf-8').splitlines():
        if not line.strip():
            continue
        seen += 1
        job = json.loads(line)
        result = run_job(job)
        expected = job.get('expected', {})
        assert result['schema'] == 'queuebash.class_inference.recommendation.v1', name
        assert result['fingerprint']['schema'] == 'queuebash.class_inference.fingerprint.v1', name
        assert isinstance(result['confidence'], (int, float)), name
        assert isinstance(result['observations'], int), name
        assert isinstance(result['reasons'], list) and result['reasons'], name
        assert result['non_mutating'] is True, name
        assert result['submit_integration'] == 'not_enabled_in_this_package', name
        assert result['decision'] in {'ok','insufficient_history','class_downgrade_suspected','class_mismatch'}, name
        assert result['recommended_action'] in {'allow','defer_to_class_policy','warn_or_require_review','block_pending_authorisation'}, name
        assert result['audit_event_preview']['decision'] == result['decision'], name
        assert result['audit_event_preview']['recommended_action'] == result['recommended_action'], name
        for key in ('decision', 'recommended_action', 'recommended_class'):
            if key in expected:
                assert result.get(key) == expected[key], (name, key, result.get(key), expected[key], result)
        if expected.get('not_recommended_action'):
            assert result['recommended_action'] != expected['not_recommended_action'], (name, result)
        if result['recommended_action'] == 'block_pending_authorisation':
            assert result['reasons'], 'blocking recommendation without reasons'
            assert result['decision'] == 'class_downgrade_suspected', result

assert seen >= 7
print(f'PASS class_classifier_json_contract_static cases={seen}')
