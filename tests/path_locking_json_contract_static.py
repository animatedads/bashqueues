#!/usr/bin/env python3
import json
import pathlib
import sys

root = pathlib.Path(__file__).resolve().parents[1]
errors = []

schema_files = [
    root / 'schemas/path_lock/profile.example.json',
    root / 'schemas/path_lock/decision.blocked.example.json',
    root / 'schemas/path_lock/decision.allowed.example.json',
]
fixture_dir = root / 'tests/fixtures/path_lock'
fixture_files = sorted(fixture_dir.glob('*.json'))

for path in schema_files + fixture_files:
    if not path.exists():
        errors.append(f'missing {path.relative_to(root)}')
        continue
    try:
        obj = json.loads(path.read_text())
    except Exception as exc:
        errors.append(f'invalid json {path.relative_to(root)}: {exc}')
        continue
    schema = obj.get('schema')
    if path.name == 'profile.example.json':
        if schema != 'queuebash.path_lock.profile.v1':
            errors.append(f'{path.name}: wrong profile schema {schema!r}')
        for key in ['canonical_path', 'parent', 'symlink_policy', 'hardlink_policy', 'mount_crossing_policy', 'open_policy', 'write_policy']:
            if key not in obj:
                errors.append(f'{path.name}: missing {key}')
        if obj.get('symlink_policy') != 'deny':
            errors.append(f'{path.name}: symlink policy must deny')
        if 'nofollow' not in obj.get('open_policy', []):
            errors.append(f'{path.name}: open_policy must include nofollow')
        if 'no-magiclinks' not in obj.get('open_policy', []):
            errors.append(f'{path.name}: open_policy must include no-magiclinks')
        parent = obj.get('parent', {})
        for key in ['device', 'inode', 'owner_uid', 'mode']:
            if key not in parent:
                errors.append(f'{path.name}: parent missing {key}')
    else:
        if schema != 'queuebash.path_lock.evidence.v1':
            errors.append(f'{path.name}: wrong evidence schema {schema!r}')
        for key in ['qid', 'status', 'reason', 'parent_identity_ok', 'final_identity_ok', 'safe_open_policy', 'write_policy']:
            if key not in obj:
                errors.append(f'{path.name}: missing {key}')
        if obj.get('redacted') is not True:
            errors.append(f'{path.name}: redacted must be true')
        if obj.get('secret_value_included') is not False:
            errors.append(f'{path.name}: secret_value_included must be false')
        if obj.get('status') not in {'allow', 'blocked'}:
            errors.append(f'{path.name}: invalid status {obj.get("status")!r}')
        policy = obj.get('safe_open_policy', '')
        for token in ['beneath', 'nofollow', 'no-magiclinks']:
            if token not in policy:
                errors.append(f'{path.name}: safe_open_policy missing {token}')

expected_reasons = {
    'symlink_denied', 'parent_identity_mismatch', 'hardlink_denied',
    'path_escape_denied', 'magiclink_denied', 'shared_tmp_denied',
    'final_identity_mismatch', 'private_workspace_create_allowed',
    'same_inode_append_allowed'
}
seen_reasons = {json.loads(p.read_text()).get('reason') for p in fixture_files if p.exists()}
missing = expected_reasons - seen_reasons
if missing:
    errors.append(f'missing fixture reasons: {sorted(missing)}')

if errors:
    for e in errors:
        print('FAIL path_locking_json_contract_static:', e, file=sys.stderr)
    sys.exit(1)
print('PASS path_locking_json_contract_static')
