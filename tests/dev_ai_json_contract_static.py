#!/usr/bin/env python3
import json
from pathlib import Path

for path in Path('schemas/dev_ai').glob('*.example.json'):
    data=json.loads(path.read_text())
    assert data.get('schema','').startswith('queuebash.dev_ai.'), path

helper=Path('bin/queue-dev-ai').read_text()
for fragment in [
    'session_start.v1',
    'session_lessons.v1',
    'try.v1',
    'lesson_result.v1',
    'session_stop.v1',
]:
    assert fragment in helper, fragment
print('PASS dev_ai_json_contract_static')
