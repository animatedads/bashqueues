#!/usr/bin/env python3
from __future__ import annotations
import json
import pathlib
import subprocess
import tempfile
import shutil

root = pathlib.Path(__file__).resolve().parents[1]
helper = root / 'providers.d' / 'remote_admin' / 'remote_admin_policy.sh'
fixture = root / 'tests' / 'fixtures' / 'remote_admin'

with tempfile.TemporaryDirectory() as td:
    t = pathlib.Path(td)
    policy = t / 'policies.d' / 'remote-queue'
    audit = t / 'var' / 'log' / 'queuebash'
    (policy / 'secrets').mkdir(parents=True)
    audit.mkdir(parents=True)
    for name in ['remote-management.env', 'clients.tsv', 'acl.tsv']:
        shutil.copy2(fixture / name, policy / name)
    plan = t / 'plan.json'
    out = subprocess.check_output([
        str(helper), '--root', str(t), '--actor', 'admin@example.invalid', '--json',
        'plan', 'create', '--out', str(plan), '--config-set', 'QUEUE_REMOTE_MANAGEMENT_ACCESS_LOG=0'
    ], text=True)
    obj = json.loads(out)
    assert obj['schema'] == 'queuebash.remote_admin.plan_create.v1'
    assert obj['plan']['schema'] == 'queuebash.remote_admin.plan.v1'
    assert obj['mutated'] is True
    assert obj['plan']['operations'][0]['action'] == 'config.set'
    out = subprocess.check_output([
        str(helper), '--root', str(t), '--actor', 'admin@example.invalid', '--json', 'apply', str(plan)
    ], text=True)
    apply = json.loads(out)
    assert apply['schema'] == 'queuebash.remote_admin.apply.v1'
    assert apply['mutated'] is True
    assert apply['rollback_id']
    out = subprocess.check_output([
        str(helper), '--root', str(t), '--actor', 'admin@example.invalid', '--json', 'rollback', 'show', apply['rollback_id']
    ], text=True)
    rb = json.loads(out)
    assert rb['schema'] == 'queuebash.remote_admin.rollback_show.v1'
    assert sorted(rb['rollback']['files']) == ['acl.tsv', 'clients.tsv', 'remote-management.env']

print('remote_admin_policy_plan_apply_json_contract_static: ok')
