#!/usr/bin/env python3
import json
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[1]
fixture = root / 'schemas' / 'display_resource' / 'resource_surface_audit_result.example.json'
with fixture.open(encoding='utf-8') as fh:
    example = json.load(fh)
assert example['schema'] == 'queuebash.display_resource_surface_audit.v1'
for key in ['manifest_only', 'resource_rendering', 'resource_body_read', 'token_substitution', 'secret_rendering', 'provider_calls', 'signing_mutation', 'install_mutation', 'permission_mutation', 'json_contract_source']:
    assert key in example, key
assert example['manifest_only'] is True
for key in ['resource_rendering', 'resource_body_read', 'token_substitution', 'secret_rendering', 'provider_calls', 'signing_mutation', 'install_mutation', 'permission_mutation', 'json_contract_source']:
    assert example[key] is False, key
assert example['status'] == 'ok'
assert isinstance(example['surfaces'], list)
assert isinstance(example['findings'], list)

proc = subprocess.run(
    [sys.executable, str(root / 'bin' / 'queue-display-resource-surface-audit.py'), '--root', str(root), '--json'],
    check=False,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
assert proc.returncode == 0, proc.stderr + proc.stdout
result = json.loads(proc.stdout)
assert result['schema'] == 'queuebash.display_resource_surface_audit.v1'
assert result['renderer'] == 'none-surface-audit-only'
assert result['summary']['audited_surfaces'] >= 2
for item in result['surfaces']:
    assert item['safe_surface'] is True, item
    assert item['surface'].strip() == item['surface'], item
    assert len(item['surface']) == item['surface_length'], item
