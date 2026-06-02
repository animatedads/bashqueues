#!/usr/bin/env python3
from pathlib import Path
qb = Path('queuebash.sh').read_text(encoding='utf-8')
required = [
    '--uses-cloud', '--cloud-profile', '--cloud-capability',
    'USES_CLOUD', 'CLOUD_PROFILE', 'CLOUD_CAPABILITY',
    'CLOUD_BROKER_DECISION', 'CLOUD_BROKER_BINDING',
    'advisory-only', 'not-bound-to-dispatch',
]
missing = [x for x in required if x not in qb]
if missing:
    raise SystemExit('missing cloud job intent contract tokens: ' + ', '.join(missing))
print('PASS')
