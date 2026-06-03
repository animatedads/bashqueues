#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
for fam, priority in [('model_registry',1),('container_registry',2),('vector_database',3),('data_lake',4)]:
    rec = service['families'][fam]
    assert rec['status'] == 'fixture_first_provider_family', fam
    assert rec['priority'] == priority, fam
    assert (root / 'providers.d' / rec['provider_dir']).is_dir(), fam
    assert (root / 'policies.d' / rec['policy_dir']).is_dir(), fam
    assert (root / 'tests/fixtures' / rec['fixture_dir']).is_dir(), fam
    assert rec['schemas'], fam
assert service['default_safety_contract']['fixture_first'] is True
assert service['default_safety_contract']['live_api_default'] is False
assert service['default_safety_contract']['normalized_json_only'] is True
assert service['next_candidates'] == ['gpu_marketplace','distributed_framework']
print('PASS provider_service_coverage_wave2_bob14_static')
