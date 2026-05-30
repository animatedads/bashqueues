#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
import json, os, shutil, subprocess, tempfile
from pathlib import Path
root = Path.cwd()
tmp = Path(tempfile.mkdtemp(prefix='queue-remote-admin-smoke.'))
try:
    policy = tmp / 'policies.d' / 'remote-queue'
    (policy / 'secrets').mkdir(parents=True)
    (tmp / 'var/log/queuebash').mkdir(parents=True)
    for name in ('remote-management.env', 'clients.tsv', 'acl.tsv'):
        shutil.copy2(root / 'tests' / 'fixtures' / 'remote_admin' / name, policy / name)
    helper = root / 'providers.d' / 'remote_admin' / 'remote_admin_policy.sh'
    def run(args, input_data=None, ok=(0,), out=None):
        cp = subprocess.run([str(helper), '--root', str(tmp), *args], input=input_data, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=15)
        if cp.returncode not in ok:
            raise AssertionError((args, cp.returncode, cp.stdout.decode(), cp.stderr.decode()))
        if out:
            Path(out).write_bytes(cp.stdout)
        return cp
    deny = run(['--actor','stranger@example.invalid','--json','config','show'], ok=(1,))
    assert json.loads(deny.stdout)['status'] == 'denied'
    show = run(['--actor','admin@example.invalid','--json','config','show'])
    seto = run(['--actor','admin@example.invalid','--reason','test','--ticket','CHG-1','--json','config','set','QUEUE_REMOTE_MANAGEMENT_ACCESS_LOG','0'])
    assert json.loads(show.stdout)['status'] == 'ok'
    assert json.loads(seto.stdout)['mutated'] is True
    assert 'QUEUE_REMOTE_MANAGEMENT_ACCESS_LOG=0' in (policy / 'remote-management.env').read_text()
    acl_deny = run(['--actor','admin@example.invalid','--json','acl','grant','london-admin','remote.queue.explain','*','test'], ok=(1,))
    assert json.loads(acl_deny.stdout)['status'] == 'denied'
    acl = run(['--actor','security-admin@example.invalid','--reason','grant','--json','acl','grant','london-admin','remote.queue.explain','*','read explain'])
    assert json.loads(acl.stdout)['rule']['operation'] == 'remote.queue.explain'
    assert 'london-admin\tremote.queue.explain\t*\tallow' in (policy / 'acl.tsv').read_text()
    secret = b'super-secret-value\n'
    s = run(['--actor','secret-admin@example.invalid','--json','secret','set','london-admin'], input_data=secret)
    assert b'super-secret-value' not in s.stdout
    sobj = json.loads(s.stdout)
    assert sobj['mutated'] is True and 'fingerprint' in sobj
    v = run(['--actor','secret-admin@example.invalid','--json','secret','verify','london-admin'], input_data=secret)
    assert json.loads(v.stdout)['verified'] is True
    audit = run(['--actor','auditor@example.invalid','--json','audit','verify'])
    aobj = json.loads(audit.stdout)
    assert aobj['status'] == 'ok' and aobj['verified'] is True
    cp = subprocess.run(['bash','-lc', 'export QUEUEBASH_ALLOW_NONINTERACTIVE=1; source ./queuebash.sh >/dev/null 2>&1; queue remote-admin --root "$0" --actor admin@example.invalid --json validate', str(tmp)], cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=15)
    if cp.returncode != 0:
        raise AssertionError((cp.returncode, cp.stdout.decode(), cp.stderr.decode()))
    assert json.loads(cp.stdout)['schema'] == 'queuebash.remote_admin.validate.v1'
finally:
    shutil.rmtree(tmp, ignore_errors=True)
print('remote_admin_policy_commands_smoke: ok')
PY
