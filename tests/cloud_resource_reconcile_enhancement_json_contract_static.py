#!/usr/bin/env python3
import json
import subprocess
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
provider = root / 'providers.d/cloud_resource/cloud_resource_provider.sh'
with tempfile.TemporaryDirectory() as reg, tempfile.TemporaryDirectory() as tmp:
    subprocess.check_call([str(provider), 'init', '--registry', reg, '--json'], stdout=subprocess.DEVNULL)
    obs = Path(tmp) / 'obs.json'
    obs.write_text(json.dumps({
        'resources': [{
            'schema': 'queuebash.cloud_resource.v1',
            'resource_id': 'json-aws-001',
            'provider': 'aws',
            'resource_type': 'vm',
            'region': 'eu-west-2',
            'status': 'available',
            'lifecycle_state': 'running',
            'capacity': {'cpu': 2, 'memory_gb': 8},
            'compliance': ['gdpr'],
            'allowed_classes': ['*'],
        }]
    }), encoding='utf-8')
    raw = subprocess.check_output([str(provider), 'reconcile', '--observations', str(obs), '--registry', reg, '--json'], text=True)
    data = json.loads(raw)
    assert data['schema'] == 'queuebash.cloud_resource_reconcile.v1'
    assert data['decision'] == 'allow'
    assert data['registry_mutation'] == 'local_only'
    assert data['live'] is False
    assert data['cloud_mutation'] is False
    for key in ('expired_claims', 'suspect_claims', 'stale_resources', 'observed_resources', 'added_resources', 'updated_resources', 'missing_resources'):
        assert key in data and isinstance(data[key], list), key
    assert 'json-aws-001' in data['observed_resources']
print('PASS cloud_resource_reconcile_enhancement_json_contract_static')
