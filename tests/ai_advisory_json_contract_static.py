#!/usr/bin/env python3
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
q = (root / "queuebash.sh").read_text()
doc = (root / "docs" / "AI_ADVISORY_PROVIDER.md").read_text()
aud = (root / "docs" / "AI_AUDIT_LOGGING.md").read_text()

assert 'schema":"queuebash.ai_advisory.request.v1"' in q
assert 'schema":"queuebash.ai_advisory.audit.v1"' in q
assert 'question_sha256' in q
assert 'question_redacted' in q
assert 'context_allowed' in q
assert 'context_denied' in q
assert 'redactions_applied' in q
assert 'provider_execution' in q
assert 'not_implemented_contract_only' in q
assert 'response_length' in q
assert 'QUEUEBASH_AI_ALLOW_QUEUE_STATUS' in q
assert 'QUEUEBASH_AI_ALLOW_POLICY_DETAILS' in q

for text in (doc, aud):
    assert 'queuebash.ai_advisory' in text
    blocks = re.findall(r"```json\n(.*?)\n```", text, re.S)
    assert blocks, "expected JSON examples"
    for block in blocks:
        json.loads(block)

print('PASS')
