#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
required = ['aws-ec2-gdpr','oci-vm-gdpr','azure-vm-gdpr','gcp-compute-gdpr','ibm-vpc-gdpr']
templates = json.loads((root / 'policies.d/cloud-provision/templates.example.json').read_text(encoding='utf-8'))['templates']
by_name = {t['name']: t for t in templates}
for name in required:
    t = by_name[name]
    assert t.get('cloud_infra_service'), f'{name} missing cloud_infra_service'
    assert t.get('registry_handoff') == 'preview-only'
    life = json.loads((root / f'examples/cloud-provision/{name}-lifecycle-plan.example.json').read_text(encoding='utf-8'))
    assert life['schema'] == 'queuebash.cloud_provision.lifecycle_plan.v1'
    assert life['decision'] == 'dry_run'
    assert life['mutated'] is False and life['live'] is False
    assert life['cloud_infra_action']['mutated'] is False
    preview = json.loads((root / f'examples/cloud-provision/{name}-registry-preview.example.json').read_text(encoding='utf-8'))
    assert preview['schema'] == 'queuebash.cloud_provision.registry_preview.v1'
    assert preview['registry_write'] is False
    assert preview['resource_record']['schema'] == 'queuebash.cloud_resource.v1'
    assert preview['resource_record']['lifecycle_state'] == 'planned'
    assert preview['resource_record']['provenance']['handoff_mode'] == 'preview-only'
print('PASS cloud_provision_registry_preview_static')
