#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
helper = root / 'providers.d' / 'enterprise' / 'maintenance_evidence_verify.sh'
valid = root / 'tests' / 'fixtures' / 'enterprise' / 'maintenance_evidence' / 'valid_approved_maintenance.json'
proc = subprocess.run([str(helper), '--request', str(valid), '--json'], cwd=root, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
obj = json.loads(proc.stdout)
assert obj['schema'] == 'queuebash.enterprise_maintenance_evidence_decision.v1'
assert obj['status'] == 'ok'
assert obj['ok'] is True
assert obj['mode'] == 'fixture-only'
assert obj['live_clearance_granted'] is False
assert obj['system_modified'] is False
for key in ['change_ticket','dual_control','signed_approval','rollback_evidence','audit_path','canonical_policy_root','secret_env_denied','secret_json_denied','external_ai_denied']:
    assert key in obj['checks'], key
for sample in ['approved_maintenance_request.example.json', 'approved_maintenance_decision.allowed.example.json', 'approved_maintenance_decision.blocked.example.json']:
    loaded = json.loads((root / 'schemas' / 'enterprise' / sample).read_text())
    assert loaded['schema'].startswith('queuebash.enterprise_maintenance_')
print('[PASS] enterprise_maintenance_evidence_json_contract_static')
