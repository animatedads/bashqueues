#!/usr/bin/env python3
import json
from pathlib import Path

q = Path('queuebash.sh').read_text()
doc = Path('docs/QUEUE_DEV_SCRATCHPAD_LIFECYCLE.md').read_text()

for schema in [
    'queuebash.dev_workflow.scratchpad_status.v1',
    'queuebash.dev_workflow.supersede.v1',
]:
    assert schema in q, f'missing {schema} in source'
    assert schema in doc, f'missing {schema} in docs'

for status in ['active', 'pending', 'in_progress', 'done', 'resolved', 'accepted', 'rejected', 'stale', 'proposed', 'blocked', 'failed', 'superseded', 'archived', 'removed']:
    assert status in q, f'missing status enum {status}'

for token in ['old_status', 'new_status', 'item_id', 'note_id', 'superseded_by', 'relations', 'supersedes']:
    assert token in q, f'missing lifecycle relation token {token}'

status_example = json.loads(Path('schemas/dev_workflow/scratchpad_status.example.json').read_text())
supersede_example = json.loads(Path('schemas/dev_workflow/supersede.example.json').read_text())
assert status_example['schema'] == 'queuebash.dev_workflow.scratchpad_status.v1'
assert {'schema', 'status', 'item_id', 'old_status', 'new_status'} <= set(status_example)
assert supersede_example['schema'] == 'queuebash.dev_workflow.supersede.v1'
assert {'schema', 'status', 'item_id', 'superseded_by'} <= set(supersede_example)

body = q[q.find('_queue_dev_scratchpad_path()'):q.find('_queue_dev_test_usage()')]
for forbidden in ['_queue_dev_test', 'generateContent', 'ollama', 'openai', 'gemini']:
    assert forbidden not in body, f'forbidden dependency in scratchpad lifecycle body: {forbidden}'

print('PASS dev_scratchpad_lifecycle_json_contract_static')
