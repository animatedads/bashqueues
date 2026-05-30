#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
helper = root / 'providers.d/cloud_signals/cloud_signals_provider.sh'
policy = json.loads((root / 'policies.d/cloud-signals/service-availability.example.json').read_text())
cost = json.loads((root / 'policies.d/cloud-signals/cost-catalog.example.json').read_text())
assert policy['schema'] == 'queuebash.cloud_signals.availability_policy.v1'
assert cost['schema'] == 'queuebash.cloud_signals.cost_catalog.v1'
for provider in ('oci','aws','azure','gcp','ibm'):
    assert provider in policy['platforms'], provider
    assert provider in cost['platforms'], provider

def run(*args):
    out = subprocess.check_output([str(helper), *args, '--json'], text=True)
    return json.loads(out)
platforms = run('platforms')
assert platforms['schema'] == 'queuebash.cloud_signals.platforms.v1'
assert {p['provider'] for p in platforms['platforms']} >= {'oci','aws','azure','gcp','ibm'}
avail = run('availability-check','--provider','azure','--region','uksouth','--service','compute')
assert avail['schema'] == 'queuebash.cloud_signals.availability.v1'
assert avail['decision'] in ('allow','review','deny')
assert avail['live'] is False
cost_ok = run('cost-check','--provider','ibm','--region','eu-gb','--service','compute','--estimated-hourly-usd','0.5','--monthly-budget-usd','750')
assert cost_ok['schema'] == 'queuebash.cloud_signals.cost.v1'
assert cost_ok['currency'] == 'USD'
assert cost_ok['live'] is False
explain = run('explain','--provider','oci','--region','uk-london-1','--service','compute','--estimated-hourly-usd','0.5','--monthly-budget-usd','750')
assert explain['schema'] == 'queuebash.cloud_signals.explain.v1'
assert explain['availability']['schema'] == 'queuebash.cloud_signals.availability.v1'
assert explain['cost']['schema'] == 'queuebash.cloud_signals.cost.v1'
print('PASS cloud_cost_service_availability_json_contract_static')
