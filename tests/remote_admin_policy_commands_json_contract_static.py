#!/usr/bin/env python3
import json
import os
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
helper = ROOT / 'providers.d' / 'remote_admin' / 'remote_admin_policy.sh'
fixture = ROOT / 'tests' / 'fixtures' / 'remote_admin'

def run(args, stdin=None, ok=True):
    p = subprocess.run([str(helper)] + args, input=stdin, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if ok and p.returncode != 0:
        raise AssertionError((p.returncode, p.stdout, p.stderr))
    if not ok and p.returncode == 0:
        raise AssertionError('expected failure')
    return json.loads(p.stdout)

with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    pol = root / 'policies.d' / 'remote-queue'
    (pol / 'secrets').mkdir(parents=True)
    (root / 'var' / 'log' / 'queuebash').mkdir(parents=True)
    for name in ['remote-management.env', 'clients.tsv', 'acl.tsv']:
        (pol / name).write_text((fixture / name).read_text())

    base = ['--root', str(root), '--json']
    denied = run(base + ['--actor', 'nobody@example.invalid', 'config', 'show'], ok=False)
    assert denied['schema'] == 'queuebash.remote_admin.response.v1'
    assert denied['status'] == 'denied'
    assert denied['mutated'] is False

    cfg = run(base + ['--actor', 'admin@example.invalid', 'config', 'show'])
    assert cfg['schema'] == 'queuebash.remote_admin.config.v1'
    assert cfg['status'] == 'ok'
    assert cfg['mutated'] is False

    acl = run(base + ['--actor', 'security-admin@example.invalid', 'acl', 'grant', 'london-admin', 'remote.queue.status', '*', 'status grant'])
    assert acl['schema'] == 'queuebash.remote_admin.acl.v1'
    assert acl['mutated'] is True

    secret = run(base + ['--actor', 'secret-admin@example.invalid', 'secret', 'set', 'london-admin'], stdin='abc123')
    assert secret['schema'] == 'queuebash.remote_admin.secret.v1'
    assert secret['mutated'] is True
    assert 'abc123' not in json.dumps(secret)

    audit = run(base + ['--actor', 'auditor@example.invalid', 'audit', 'verify'])
    assert audit['schema'] == 'queuebash.remote_admin.audit_read.v1'
    assert audit['verified'] is True

print('remote_admin_policy_commands_json_contract_static: ok')
