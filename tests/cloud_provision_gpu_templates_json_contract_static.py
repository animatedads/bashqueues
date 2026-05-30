#!/usr/bin/env python3
import json, pathlib, subprocess, sys
root = pathlib.Path(__file__).resolve().parents[1]
templates = json.loads((root/'policies.d/cloud-provision/templates.example.json').read_text())
items = {t['name']: t for t in templates['templates']}
required = ['gpu-coreweave-a100-training','gpu-lambda-h100-training','gpu-dgx-export-review','bad-gpu-cost-breach']
missing = [x for x in required if x not in items]
assert not missing, missing
for name in required[:-1]:
    t = items[name]
    assert t['provider'] == 'gpu-cloud'
    assert t['allow_live'] is False
    assert 'cloud_infra_service' in t
    assert t['resource_type'] in {'gpu-vm','gpu-cluster'}
    assert t['capacity']['gpu']['vendor'] == 'nvidia'
reg = json.loads((root/'policies.d/cloud-infra/registry.example.json').read_text())
service_ids = {s['id'] for s in reg['services']}
for name in required[:-1]:
    assert items[name]['cloud_infra_service'] in service_ids
cmd = [str(root/'providers.d/cloud_provision/cloud_provision.sh'), 'plan', 'gpu-dgx-export-review', '--json']
plan = json.loads(subprocess.check_output(cmd, text=True))
assert plan['schema'] == 'queuebash.cloud_provision.plan.v1'
assert plan['provider'] == 'gpu-cloud'
assert plan['decision'] == 'allow'
assert plan['live_mutation'] is False
assert plan['mutated'] is False
life = json.loads(subprocess.check_output([str(root/'providers.d/cloud_provision/cloud_provision.sh'), 'lifecycle-plan', 'gpu-dgx-export-review', '--json'], text=True))
assert life['schema'] == 'queuebash.cloud_provision.lifecycle_plan.v1'
assert life['decision'] == 'dry_run'
assert life['live'] is False and life['mutated'] is False
bad = subprocess.run([str(root/'providers.d/cloud_provision/cloud_provision.sh'), 'plan', 'bad-gpu-cost-breach', '--json'], text=True, stdout=subprocess.PIPE, check=False)
assert bad.returncode == 0
badj = json.loads(bad.stdout)
assert badj['decision'] == 'deny'
assert any(g['reason'] == 'cost_ceiling_breach' for g in badj['policy_gates'])
