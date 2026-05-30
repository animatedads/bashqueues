#!/usr/bin/env python3
from pathlib import Path
s = Path('queuebash.sh').read_text()
required = [
    'queuebash.dev_test_result.v1', 'harness_root', 'created_job_id', 'job_id',
    'class', 'queue_state', 'status', 'exit_code', 'timed_out',
    'duration_seconds', 'log_file', 'log_tail', 'before', 'after', 'diagnostic'
]
missing = [x for x in required if x not in s]
if missing:
    raise SystemExit(f'missing dev test JSON contract fields: {missing}')
print('PASS dev_test_runner_json_contract_static')
