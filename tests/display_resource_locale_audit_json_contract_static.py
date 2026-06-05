#!/usr/bin/env python3
import json
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[1]
fixture = root / 'schemas' / 'display_resource' / 'resource_locale_audit_result.example.json'
with fixture.open(encoding='utf-8') as fh:
    example = json.load(fh)
assert example['schema'] == 'queuebash.display_resource_locale_audit.v1'
for key in ['resource_rendering', 'token_substitution', 'secret_rendering', 'provider_calls', 'signing_mutation', 'install_mutation', 'permission_mutation', 'json_contract_source']:
    assert example[key] is False, key
assert example['status'] == 'ok'
assert isinstance(example['resources'], list)

proc = subprocess.run(
    [sys.executable, str(root / 'bin' / 'queue-display-resource-locale-audit.py'), '--root', str(root), '--json'],
    check=False,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
assert proc.returncode == 0, proc.stderr + proc.stdout
result = json.loads(proc.stdout)
assert result['schema'] == 'queuebash.display_resource_locale_audit.v1'
assert result['renderer'] == 'none-locale-audit-only'
assert result['summary']['resource_type_count'] == 2
for item in result['resources']:
    assert item['fallback_manifested'] is True, item
    assert item['fallback_directory_present'] is True, item
    assert 'fallback' in item['languages_in_manifest'], item
    assert 'fallback' in item['language_directories'], item
