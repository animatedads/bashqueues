#!/usr/bin/env python3
from pathlib import Path
import re

q = Path('queuebash.sh').read_text()
doc = Path('docs/DEV_SCRATCHPAD.md').read_text()

for schema in [
    'queuebash.dev_scratchpad.v1',
    'queuebash.dev_scratchpad_item.v1',
    'queuebash.dev_scratchpad_working_set.v1',
]:
    assert schema in q, f'missing {schema} in queuebash.sh'
    assert schema in doc, f'missing {schema} in docs'

for field in [
    'id', 'schema', 'kind', 'status', 'authority', 'text', 'tags',
    'created_at', 'updated_at', 'provenance', 'counters', 'success', 'failure'
]:
    assert field in q, f'missing item field {field}'

for value in [
    'architect', 'team_leader', 'reviewer', 'coding_agent', 'tool', 'source_tree',
    'test_runner', 'external_ai', 'imported_doc', 'authoritative', 'accepted',
    'observed', 'inferred', 'proposed', 'rejected', 'stale', 'contract',
    'design_goal', 'architecture', 'task', 'attempt', 'evidence', 'failure',
    'success', 'decision', 'toolchain', 'known_landmine', 'blocker', 'challenge',
    'done_note', 'imported_fact', 'active', 'pending', 'done', 'blocked', 'removed'
]:
    assert value in q or value in doc, f'missing enum value {value}'

assert 'command_list' in q and 'command_delete' in q, 'list/delete commands missing'
assert 'queue dev scratchpad list' in doc and 'queue dev scratchpad delete' in doc, 'list/delete docs missing'
assert 'current_task_id' in q, 'working set missing current task'
assert 'full_item_count' in q and 'pruned_item_count' in q, 'working set missing pruning counters'
assert 'export --json' in doc and 'full chronological ledger' in doc, 'export/full ledger distinction missing'
assert 'next --json' in doc and 'pruned working set' in doc, 'next/pruned distinction missing'
body = q[q.find('_queue_dev_scratchpad_path()'):q.find('_queue_dev_test_usage()')]
for forbidden in ['_queue_dev_test', 'queue dev test --scratchpad', 'generateContent', 'ollama', 'openai', 'gemini']:
    assert forbidden not in body, f'forbidden scratchpad dependency/hook: {forbidden}'
assert re.search(r'def import_facts\(', q), 'missing lightweight import helper'
assert 'source_tree' in q and 'observed' in q, 'source_tree observed import contract missing'
print('PASS dev_scratchpad_json_contract_static')
