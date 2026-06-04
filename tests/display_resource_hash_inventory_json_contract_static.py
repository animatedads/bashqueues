#!/usr/bin/env python3
import json
from pathlib import Path

payload = json.loads(Path('schemas/display_resource/resource_hash_inventory_result.example.json').read_text())
assert payload['schema'] == 'queuebash.display_resource_hash_inventory.v1'
assert payload['status'] == 'ok'
assert payload['redacted'] is True
assert payload['read_only'] is True
assert payload['installer'] is False
assert payload['signing_mutation'] is False
assert payload['json_contract_source'] is False
assert payload['secret_rendering_allowed'] is False
assert payload['token_value_substitution'] is False
assert payload['permission_mutation'] is False
assert payload['hash_algorithm'] == 'sha256'
assert payload['renderer'] == 'none-hash-inventory-only'
assert payload['source'] == 'manifest-listed-files-and-sha256-only'
assert isinstance(payload['manifests'], list)
assert isinstance(payload['resources'], list)
assert isinstance(payload['findings'], list)
assert payload['resources'][0]['hash_status'] == 'ok'
assert len(payload['resources'][0]['sha256']) == 64
for forbidden in ['resource_rendering', 'token_substitution', 'secret_values', 'signing_mutation', 'install_mutation']:
    assert forbidden in payload['forbidden']
