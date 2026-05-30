#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
import json, shutil, subprocess, tempfile
from pathlib import Path
root = Path.cwd()
tmp = Path(tempfile.mkdtemp(prefix='queue-remote-admin-dual-control.'))
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
        return json.loads(cp.stdout.decode() or '{}')

    # Non-ACL transaction remains single-control and applies normally.
    cfg_plan = tmp / 'config-plan.json'
    run(['--actor','admin@example.invalid','--json','plan','create','--out',str(cfg_plan),
         '--config-set','QUEUE_REMOTE_MANAGEMENT_ACCESS_LOG=0'])
    cfg_apply = run(['--actor','admin@example.invalid','--json','apply',str(cfg_plan)])
    assert cfg_apply['status'] == 'ok'
    assert cfg_apply['checks'][0]['operation'] == 'remote-admin.plan.dual-control'
    assert cfg_apply['checks'][0]['allowed'] is True
    assert cfg_apply['checks'][0]['reason'] == 'not_required'

    acl_plan = tmp / 'acl-plan.json'
    created = run(['--actor','admin@example.invalid','--json','plan','create','--out',str(acl_plan),
                   '--acl-grant','london-admin:remote.queue.status:*:temporary status grant'])
    assert created['plan']['requires_dual_control'] is True
    assert created['plan']['approvals'] == []

    denied = run(['--actor','security-admin@example.invalid','--json','apply',str(acl_plan)], ok=(1,))
    assert denied['status'] == 'denied'
    assert denied['operation'] == 'remote-admin.plan.apply'
    assert 'dual' in denied['reason'] or 'approve' in denied['reason']

    self_denied = run(['--actor','admin@example.invalid','--json','plan','approve',str(acl_plan)], ok=(1,))
    assert self_denied['status'] == 'denied'
    assert self_denied['operation'] == 'remote-admin.plan.approve'
    assert 'distinct' in self_denied['reason']

    approved = run(['--actor','security-admin@example.invalid','--reason','approved ACL change','--ticket','CHG-ACL',
                    '--json','plan','approve',str(acl_plan)])
    assert approved['status'] == 'ok'
    assert approved['schema'] == 'queuebash.remote_admin.plan_approve.v1'
    assert approved['approval']['approver'] == 'security-admin@example.invalid'
    assert approved['plan']['approvals']

    applied = run(['--actor','security-admin@example.invalid','--json','apply',str(acl_plan)])
    assert applied['status'] == 'ok'
    assert applied['schema'] == 'queuebash.remote_admin.apply.v1'
    assert applied['checks'][0]['operation'] == 'remote-admin.plan.dual-control'
    assert applied['checks'][0]['reason'] == 'approved'
    assert any(c['operation'] == 'remote-admin.acl.write' and c['allowed'] for c in applied['checks'])
    acl_text = (policy / 'acl.tsv').read_text()
    assert 'london-admin\tremote.queue.status\t*\tallow\ttemporary status grant' in acl_text
finally:
    shutil.rmtree(tmp, ignore_errors=True)
print('remote_admin_policy_dual_control_smoke: ok')
PY
