#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
policy = json.loads((root / 'policies.d/cloud-resource/provider-parity-report.json').read_text(encoding='utf-8'))
assert policy['schema'] == 'queuebash.provider_parity_report_policy.v1'
assert policy['security_boundary']['live_api_calls'] is False
assert policy['security_boundary']['credentials_required'] is False
assert policy['security_boundary']['cloud_mutation'] is False
assert policy['security_boundary']['queue_dispatch_refactor'] is False
families = policy['families']
expected = {'aws','azure','gcp','oci','ibm','eu_sovereign','apac_china','gpu_cloud','edge_cloud','hybrid_onprem'}
assert expected.issubset(families), sorted(expected - set(families))
for family, spec in families.items():
    for key in ('docs','provider_dirs','policies','fixtures','tests'):
        assert key in spec and isinstance(spec[key], list) and spec[key], (family, key)

out = subprocess.check_output([
    str(root / 'providers.d/cloud_resource/provider_parity_report.py'), '--root', str(root), '--json'
], text=True)
report = json.loads(out)
assert report['schema'] == 'queuebash.provider_parity_report.v1'
assert report['summary']['families_incomplete'] == 0, report['summary']
assert report['live_api_calls'] is False
assert report['credentials_required'] is False
assert report['cloud_mutation'] is False
assert report['queue_dispatch_refactor'] is False
for row in report['families']:
    assert row['decision'] in {'allow','deny'}
    assert 'reason' in row
    assert 'coverage_score' in row
    assert set(row['buckets']).issuperset({'docs','provider_dirs','policies','fixtures','tests'})
print('PASS provider_parity_report_json_contract_static')
