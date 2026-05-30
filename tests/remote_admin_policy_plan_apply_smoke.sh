#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
import json, shutil, subprocess, tempfile
from pathlib import Path
root = Path.cwd()
tmp = Path(tempfile.mkdtemp(prefix='queue-remote-admin-plan-smoke.'))
try:
    policy = tmp / 'policies.d' / 'remote-queue'
    (policy / 'secrets').mkdir(parents=True)
    (tmp / 'var/log/queuebash').mkdir(parents=True)
    for name in ('remote-management.env', 'clients.tsv', 'acl.tsv'):
        shutil.copy2(root / 'tests' / 'fixtures' / 'remote_admin' / name, policy / name)
    helper = root / 'providers.d' / 'remote_admin' / 'remote_admin_policy.sh'

    def run(args, ok=(0,), input_data=None, timeout=20):
        cp = subprocess.run([str(helper), '--root', str(tmp), *args], input=input_data,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
        if cp.returncode not in ok:
            raise AssertionError((args, cp.returncode, cp.stdout.decode(), cp.stderr.decode()))
        return cp

    deny = run(['--actor','stranger@example.invalid','--json','plan','create','--config-set','QUEUE_REMOTE_MANAGEMENT_ACCESS_LOG=0'], ok=(1,))
    obj = json.loads(deny.stdout)
    assert obj['status'] == 'denied'
    assert obj['operation'] == 'remote-admin.plan.write'

    plan = tmp / 'remote-admin-plan.json'
    created = run(['--actor','admin@example.invalid','--reason','plan','--ticket','CHG-PLAN','--json',
                   'plan','create','--out',str(plan),'--config-set','QUEUE_REMOTE_MANAGEMENT_ACCESS_LOG=0'])
    cobj = json.loads(created.stdout)
    assert cobj['status'] == 'ok'
    assert cobj['schema'] == 'queuebash.remote_admin.plan_create.v1'
    assert cobj['mutated'] is True
    assert plan.exists()
    assert cobj['plan']['operations'][0]['action'] == 'config.set'

    applied = run(['--actor','admin@example.invalid','--reason','apply','--ticket','CHG-PLAN','--json','apply',str(plan)])
    aobj = json.loads(applied.stdout)
    assert aobj['status'] == 'ok'
    assert aobj['schema'] == 'queuebash.remote_admin.apply.v1'
    assert aobj['mutated'] is True
    assert aobj['rollback_id'] and aobj['rollback_id'] != 'dry-run'
    assert aobj['checks'][0]['allowed'] is True
    assert 'QUEUE_REMOTE_MANAGEMENT_ACCESS_LOG=0' in (policy / 'remote-management.env').read_text()

    rid = aobj['rollback_id']
    shown = run(['--actor','admin@example.invalid','--json','rollback','show',rid])
    restored = run(['--actor','admin@example.invalid','--reason','rollback','--json','rollback','apply',rid])
    sobj = json.loads(shown.stdout)
    robj = json.loads(restored.stdout)
    assert sobj['status'] == 'ok' and 'files' in sobj['rollback']
    assert robj['status'] == 'ok' and robj['mutated'] is True
    assert 'QUEUE_REMOTE_MANAGEMENT_ACCESS_LOG=' not in (policy / 'remote-management.env').read_text()

    aclplan = tmp / 'remote-admin-acl-plan.json'
    run(['--actor','admin@example.invalid','--json','plan','create','--out',str(aclplan),
         '--acl-grant','london-admin:remote.queue.status:*:temporary status grant'])
    acl_deny = run(['--actor','admin@example.invalid','--json','apply',str(aclplan)], ok=(1,))
    dobj = json.loads(acl_deny.stdout)
    assert dobj['status'] == 'denied'
    assert dobj['operation'] == 'remote-admin.plan.apply'
    assert 'dual' in dobj.get('reason','') or 'approve' in dobj.get('reason','')

    plan_deny = run(['--actor','security-admin@example.invalid','--json','apply',str(aclplan)], ok=(1,))
    pobj = json.loads(plan_deny.stdout)
    assert pobj['status'] == 'denied'
    assert pobj['operation'] == 'remote-admin.plan.apply'
    assert 'dual' in pobj.get('reason','') or 'approve' in pobj.get('reason','')
finally:
    shutil.rmtree(tmp, ignore_errors=True)
print('remote_admin_policy_plan_apply_smoke: ok')
PY
