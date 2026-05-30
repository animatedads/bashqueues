#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
doc = (root / 'docs/CLOUD_PLATFORM_PARITY.md').read_text(encoding='utf-8')
assert 'platform coverage is not equal yet' in doc
assert 'AWS is first-tier for contract coverage' in doc
assert 'GCP are first-tier for contract coverage' in doc or 'GCP | yes | yes | yes | yes | yes' in doc
assert 'Azure and GCP are promoted to first-tier' in doc or 'Azure | yes | yes | yes | yes | yes' in doc
assert 'EU sovereign provider contracts now exist' in doc
assert 'APAC/China provider contracts now exist' in doc
assert 'GPU cloud provider contracts now exist' in doc
assert 'Edge cloud provider contracts now exist' in doc
matrix = json.loads((root / 'policies.d/cloud-resource/platform-parity.json').read_text(encoding='utf-8'))
assert matrix['verdict'] == 'not_equal_yet'
platforms = matrix['platforms']
assert set(['oci','ibm','azure','gcp','aws','eu_sovereign','apac_china','gpu_cloud','edge_cloud']).issubset(platforms)
assert platforms['aws']['first_class']
assert platforms['aws']['governance']
assert platforms['aws']['gdpr_data_protection']
assert platforms['aws']['itar_export_control']
assert platforms['aws']['finops_cost']
assert platforms['gcp']['provider_json_contract']
assert platforms['gcp']['governance']
assert platforms['gcp']['fixtures']
assert platforms['gcp']['static_smoke_json_tests']
assert platforms['gcp']['first_class']
assert platforms['gcp']['finops_cost']
assert platforms['gcp']['itar_export_control']
assert platforms['azure']['first_class']
assert platforms['azure']['finops_cost']
assert platforms['azure']['itar_export_control']
assert platforms['eu_sovereign']['provider_json_contract']
assert platforms['eu_sovereign']['fixtures']
assert not platforms['eu_sovereign']['first_class']
assert platforms['apac_china']['provider_json_contract']
assert platforms['apac_china']['fixtures']
assert platforms['apac_china']['static_smoke_json_tests']
assert not platforms['apac_china']['first_class']
assert platforms['gpu_cloud']['provider_json_contract']
assert platforms['gpu_cloud']['fixtures']
assert platforms['gpu_cloud']['static_smoke_json_tests']
assert not platforms['gpu_cloud']['first_class']
assert platforms['edge_cloud']['provider_json_contract']
assert platforms['edge_cloud']['fixtures']
assert platforms['edge_cloud']['static_smoke_json_tests']
assert not platforms['edge_cloud']['first_class']

assert platforms['azure']['provider_json_contract']
assert platforms['azure']['fixtures']
assert platforms['azure']['static_smoke_json_tests']
assert platforms['oci']['governance']
assert platforms['ibm']['finops_cost']
print('PASS cloud_platform_parity_static')

# 0.18.41 hybrid/on-prem provider family
assert 'hybrid_onprem' in platforms
assert platforms['hybrid_onprem']['provider_json_contract']
assert platforms['hybrid_onprem']['governance']
assert platforms['hybrid_onprem']['fixtures']
assert not platforms['hybrid_onprem']['first_class']
