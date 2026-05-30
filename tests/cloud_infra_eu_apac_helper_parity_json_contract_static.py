#!/usr/bin/env python3
import json
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent
registry = ROOT / 'tests' / 'fixtures' / 'cloud_infra' / 'registry.json'
cmd = [str(ROOT / 'providers.d' / 'cloud_infra' / 'cloud_infra.sh')]

def run(*args):
    out = subprocess.check_output(cmd + list(args), cwd=ROOT, env={
        'QUEUEBASH_CLOUD_INFRA_REGISTRY': str(registry),
        'QUEUEBASH_CLOUD_INFRA_LIVE': '0',
        'PATH': '/usr/bin:/bin',
    }, text=True)
    return json.loads(out)

expected = {
    'ovh-gdpr-vm': ('ovhcloud', 'eu_sovereign'),
    'scaleway-gdpr-instance': ('scaleway', 'eu_sovereign'),
    'hetzner-gdpr-cloud': ('hetzner', 'eu_sovereign'),
    'otc-gdpr-ecs': ('otc', 'eu_sovereign'),
    'alibaba-export-review-ecs': ('alibaba', 'apac_china'),
    'tencent-export-review-cvm': ('tencent', 'apac_china'),
    'huawei-export-review-ecs': ('huawei', 'apac_china'),
}
for service, (provider, family) in expected.items():
    d = run('plan', service, 'start')
    required = {'schema','provider','provider_family','helper','service_id','action','decision','reason','registry_checked','live','mutated','planned_only','fail_closed','legal','cost'}
    assert required.issubset(d), (service, sorted(required - set(d)))
    assert d['schema'] == 'queuebash.cloud_infra.action.v1'
    assert d['service_id'] == service
    assert d['provider'] == provider
    assert d['provider_family'] == family
    assert d['decision'] == 'dry_run'
    assert d['live'] is False
    assert d['mutated'] is False
    assert d['planned_only'] is True
    assert d['registry_checked'] is True

with open(ROOT / 'policies.d' / 'cloud-infra' / 'registry.example.json', encoding='utf-8') as fh:
    reg = json.load(fh)
ids = {svc['id'] for svc in reg['services']}
assert expected.keys() <= ids
print('cloud_infra_eu_apac_helper_parity_json_contract_static: PASS')
