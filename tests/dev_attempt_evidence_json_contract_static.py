#!/usr/bin/env python3
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
text=(root/'queuebash.sh').read_text()
for needle in [
    'queuebash.dev_workflow.attempt_store.v1',
    'queuebash.dev_workflow.attempt.v1',
    'queuebash.dev_workflow.evidence.v1',
    'attempt_id',
    'evidence_id',
    'text_hash',
]:
    assert needle in text, f'missing {needle}'
example_attempt={
    'schema':'queuebash.dev_workflow.attempt.v1',
    'status':'ok',
    'phase':'begin',
    'attempt_id':'DEVATTEMPT-EXAMPLE',
    'authority':'coding_agent',
    'tags':['bob12'],
    'based_on':['SP-EXAMPLE'],
    'text_hash':'sha256:example',
}
example_evidence={
    'schema':'queuebash.dev_workflow.evidence.v1',
    'status':'ok',
    'evidence_id':'DEVEVIDENCE-EXAMPLE',
    'attempt_id':'DEVATTEMPT-EXAMPLE',
    'result':'pass',
    'commands':['bash -n queuebash.sh'],
    'files':['queuebash.sh'],
}
json.dumps(example_attempt, sort_keys=True)
json.dumps(example_evidence, sort_keys=True)
print('PASS dev_attempt_evidence_json_contract_static')
