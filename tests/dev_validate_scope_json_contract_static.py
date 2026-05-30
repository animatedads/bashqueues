#!/usr/bin/env python3
import json, pathlib, re
root=pathlib.Path(__file__).resolve().parents[1]
q=(root/'queuebash.sh').read_text()
assert 'queuebash.dev_validate_result.v1' in q
assert 'queuebash.dev_scope_check_result.v1' in q
assert '_queue_dev_validate_command' in q
assert '_queue_dev_scope_check_command' in q
assert 'bin/queue-dev-timeout' in q
for doc in ['docs/QUEUE_DEV_VALIDATE_SCOPE.md']:
    text=(root/doc).read_text()
    assert 'queue dev validate' in text
    assert 'queue dev scope-check' in text
print(json.dumps({'status':'pass','schema':'queuebash.dev_validate_scope_contract_static.v1'}))
