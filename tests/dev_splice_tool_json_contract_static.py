#!/usr/bin/env python3
from pathlib import Path
import re

q = Path('queuebash.sh').read_text()
doc = Path('docs/DEV_SPLICE_TOOL.md').read_text()
for text, name in [(q, 'queuebash.sh'), (doc, 'docs/DEV_SPLICE_TOOL.md')]:
    assert 'queuebash.dev_splice_response.v1' in text, f'missing schema in {name}'

fields = [
    'schema', 'file', 'mode', 'anchor_found', 'occurrences', 'changed',
    'skipped', 'error', 'reason', 'dry_run', 'bytes_before', 'bytes_after'
]
for field in fields:
    assert re.search(rf'"{re.escape(field)}"', q) or field in doc, f'missing JSON field {field}'

assert 'os.replace(tmp, path)' in q, 'missing atomic replace'
assert 'os.chmod(tmp' in q, 'missing chmod permission preservation'
assert 'eval ' not in q[q.find('_queue_dev_splice()'):q.find('_queue_dev_command()')], 'splice must not eval content'
print('PASS dev_splice_tool_json_contract_static')
