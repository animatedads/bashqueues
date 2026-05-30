#!/usr/bin/env python3
import json
import re
import subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
q = (root / 'queuebash.sh').read_text()
assert 'queuebash.ask_provider.discovery.v1' in q
assert 'queuebash.ask_provider.list.v1' in q
assert 'queuebash.ask_provider.fixture_test.v1' in q
assert 'supports_context_refs' in q
assert 'live_call_performed' in q
for docname in ['ASK_PROVIDER_CONTRACT.md','ASK_CONTEXT_BUNDLES.md','ASK_AUDIT_LOGGING.md']:
    text=(root/'docs'/docname).read_text()
    for block in re.findall(r"```json\n(.*?)\n```", text, re.S):
        json.loads(block)
print('PASS')
