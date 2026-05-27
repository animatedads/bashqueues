#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
q = (root / 'queuebash.sh').read_text()
ollama = (root / 'bin' / 'queue-ai-ask-ollama').read_text()
gemini = (root / 'bin' / 'queue-ai-ask-gemini').read_text()

required_shell = [
    '_queue_ai_detect_job_ids',
    '_queue_ai_build_dynamic_context',
    '_queue_ai_queue_status_text',
    '_queue_ai_job_status_text',
    'QUEUEBASH_AI_ALLOW_JOB_TAIL',
    'dynamic_context_sha256',
    'job_ids_detected',
    'job_context_collected',
    'queue_status_collected',
    'response_sha256',
    'tail_included',
    'redactions_applied',
    'command_payload_redacted: true',
    'stdout_stderr_redacted: true',
]
for needle in required_shell:
    assert needle in q, needle

for helper in (ollama, gemini):
    assert 'combined_context = dynamic_context_text' in helper
    assert 'Do not invent queue commands' in helper
    assert 'If current status context is denied, say it is denied' in helper
    assert '<dynamic-shell-context>' in helper

assert 'assets.d/net_usage.sh' not in [p.as_posix() for p in (root / 'assets.d').glob('*')]
print('PASS')
