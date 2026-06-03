#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

python3 - <<'PY'
from pathlib import Path
qb=Path('queuebash.sh').read_text()
helper=Path('bin/queue-dev-ai').read_text()
required_qb=[
    'queue dev ai discover|session|try|lesson [--json]',
    'ai|llm-session|ai-session)',
    'queue-dev-ai',
]
required_helper=[
    'discover.v1',
    'session_start.v1',
    'try.v1',
    'lesson_result.v1',
    'ai_lessons.d',
    'allowed_command',
    'blocked_by_lesson',
    'confirm-lesson',
]
missing=[x for x in required_qb if x not in qb] + [x for x in required_helper if x not in helper]
if missing:
    raise SystemExit('missing dev ai contract fragments: '+', '.join(missing))
for path in [
    'docs/QUEUE_DEV_AI_SESSIONS.md',
    'docs/QUEUE_DEV_AI_LESSONS.md',
    'schemas/dev_ai/session_start.example.json',
    'schemas/dev_ai/try.example.json',
    'schemas/dev_ai/lesson.example.json',
]:
    if not Path(path).exists():
        raise SystemExit(f'missing {path}')
print('PASS dev_ai_contract_static')
PY
