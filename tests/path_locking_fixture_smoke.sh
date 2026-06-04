#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import json, pathlib, sys
root = pathlib.Path('tests/fixtures/path_lock')
blocked = {
    'symlink_pivot_blocked.json': 'symlink_denied',
    'parent_replaced_blocked.json': 'parent_identity_mismatch',
    'hardlink_misuse_blocked.json': 'hardlink_denied',
    'dotdot_escape_blocked.json': 'path_escape_denied',
    'proc_magiclink_blocked.json': 'magiclink_denied',
    'shared_tmp_high_risk_blocked.json': 'shared_tmp_denied',
    'stale_inode_blocked.json': 'final_identity_mismatch',
}
allowed = {
    'private_workspace_create_allowed.json': 'private_workspace_create_allowed',
    'append_same_inode_allowed.json': 'same_inode_append_allowed',
}
errors=[]
for name, reason in blocked.items():
    obj=json.loads((root/name).read_text())
    if obj.get('status') != 'blocked': errors.append(f'{name}: expected blocked')
    if obj.get('reason') != reason: errors.append(f'{name}: wrong reason')
    if obj.get('final_identity_ok') is True and reason not in {'parent_identity_mismatch','shared_tmp_denied'}:
        errors.append(f'{name}: unsafe final identity marked true')
for name, reason in allowed.items():
    obj=json.loads((root/name).read_text())
    if obj.get('status') != 'allow': errors.append(f'{name}: expected allow')
    if obj.get('reason') != reason: errors.append(f'{name}: wrong reason')
    if obj.get('parent_identity_ok') is not True: errors.append(f'{name}: parent identity not true')
for path in root.glob('*.json'):
    text=path.read_text().lower()
    for forbidden in ['secret_value":"', 'password', 'token=']:
        if forbidden in text:
            errors.append(f'{path.name}: forbidden leak marker {forbidden}')
if errors:
    for e in errors: print('FAIL path_locking_fixture_smoke:', e, file=sys.stderr)
    sys.exit(1)
print('PASS path_locking_fixture_smoke')
PY
