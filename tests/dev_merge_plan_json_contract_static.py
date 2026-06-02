#!/usr/bin/env python3
from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
helper=(root/'bin/queue-dev-merge-plan.py').read_text(encoding='utf-8')
doc=(root/'docs/QUEUE_DEV_MERGE_PLAN.md').read_text(encoding='utf-8')
required=[
    'queuebash.dev_merge_plan.v1',
    'members_scanned',
    'members_extracted',
    'extracted_bytes',
    'space_safety',
    'release_identity_overlap',
    'ledger_overlap_not_runtime_conflict',
    'scratchpad_distinct_items',
    'delivery_evidence',
    'validation_plan',
    'static_fallback_used',
    'manifest_warnings',
    'zero_entry_patchset',
    'unsupported_manifest_shape',
    'container_member',
    'main_test_function',
]
for token in required:
    assert token in helper or token in doc, token
assert 'extractall' not in helper
print('PASS dev_merge_plan_json_contract_static')
