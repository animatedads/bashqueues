#!/usr/bin/env python3
import json
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[1]
fixture = root / 'schemas' / 'display_resource' / 'resource_namespace_audit_result.example.json'
with fixture.open(encoding='utf-8') as fh:
    example = json.load(fh)
assert example['schema'] == 'queuebash.display_resource_namespace_audit.v1'
for key in ['resource_rendering', 'token_substitution', 'secret_rendering', 'provider_calls', 'signing_mutation', 'install_mutation', 'permission_mutation', 'json_contract_source']:
    assert example[key] is False, key
assert example['status'] == 'ok'
assert isinstance(example['names'], list)
assert isinstance(example['findings'], list)

proc = subprocess.run(
    [sys.executable, str(root / 'bin' / 'queue-display-resource-namespace-audit.py'), '--root', str(root), '--json'],
    check=False,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
assert proc.returncode == 0, proc.stderr + proc.stdout
result = json.loads(proc.stdout)
assert result['schema'] == 'queuebash.display_resource_namespace_audit.v1'
assert result['renderer'] == 'none-namespace-audit-only'
assert result['summary']['audited_names'] >= 2
for item in result['names']:
    assert item['safe_namespace'] is True, item
    assert '..' not in item['components'], item
    if item['resource_type'] == 'xml':
        assert item['extension'] == '.xml', item
