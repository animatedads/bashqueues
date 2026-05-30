#!/usr/bin/env python3
from __future__ import annotations
import json
import pathlib
import shutil
import subprocess
import tempfile

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
    plan = t / 'acl-plan.json'
    created = subprocess.check_output([
        str(helper), '--root', str(t), '--actor', 'admin@example.invalid', '--json',
        'plan', 'create', '--out', str(plan), '--acl-grant', 'client-a:remote.queue.status:*:temporary'
    ], text=True)
    cobj = json.loads(created)
    assert cobj['schema'] == 'queuebash.remote_admin.plan_create.v1'
    assert cobj['plan']['requires_dual_control'] is True
    assert cobj['plan']['approvals'] == []
    approved = subprocess.check_output([
        str(helper), '--root', str(t), '--actor', 'security-admin@example.invalid', '--json',
        'plan', 'approve', str(plan), '--note', 'reviewed'
    ], text=True)
    aobj = json.loads(approved)
    assert aobj['schema'] == 'queuebash.remote_admin.plan_approve.v1'
    assert aobj['approval']['schema'] == 'queuebash.remote_admin.plan_approval.v1'
    assert aobj['approval']['operation'] == 'remote-admin.plan.approve'
    assert aobj['approval']['plan_hash']
    applied = subprocess.check_output([
        str(helper), '--root', str(t), '--actor', 'security-admin@example.invalid', '--json', 'apply', str(plan)
    ], text=True)
    ap = json.loads(applied)
    assert ap['schema'] == 'queuebash.remote_admin.apply.v1'
    assert ap['checks'][0]['operation'] == 'remote-admin.plan.dual-control'
    assert ap['checks'][0]['reason'] == 'approved'
    assert ap['checks'][0]['approval']['approver'] == 'security-admin@example.invalid'
print('remote_admin_policy_dual_control_json_contract_static: ok')
