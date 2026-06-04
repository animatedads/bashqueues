#!/usr/bin/env python3
import json
from pathlib import Path

fixtures = [
    Path("tests/fixtures/enterprise/hospital_live_readonly_profile.expected.json"),
    Path("tests/fixtures/enterprise/hospital_live_maintenance_profile.expected.json"),
]
for path in fixtures:
    obj = json.loads(path.read_text())
    assert obj["schema"] == "queuebash.enterprise_profile.v1", obj
    assert obj["profile"].startswith("hospital-live-"), obj
    assert "status" in obj["allowed_actions"], obj
    assert "show" in obj["allowed_actions"], obj
    assert "explain" in obj["allowed_actions"], obj
    assert obj["secrets"]["delivery"] == "file", obj
    assert obj["secrets"]["env_allowed"] is False, obj
    assert obj["secrets"]["redacted_audit"] is True, obj
    assert obj["secrets"]["secret_value_in_json_allowed"] is False, obj

readonly = json.loads(fixtures[0].read_text())
assert readonly["live_clearance"] == "readonly-only"
for action in ("submit", "run", "secret-deliver", "break-glass-deliver"):
    assert action in readonly["blocked_actions"], readonly
assert readonly["approval_required_actions"] == [], readonly
assert readonly["secrets"]["delivery_allowed"] is False, readonly
assert readonly["secrets"]["break_glass_allowed"] is False, readonly

maintenance = json.loads(fixtures[1].read_text())
assert maintenance["live_clearance"] == "approved-maintenance-only"
for action in ("maintenance-execute", "secret-deliver", "break-glass-request", "break-glass-approve"):
    assert action in maintenance["approval_required_actions"], maintenance
for action in ("cloud-destroy", "policy-edit", "model-output-execution"):
    assert action in maintenance["blocked_actions"], maintenance
assert maintenance["secrets"]["delivery_allowed"] == "approved-only", maintenance
assert maintenance["secrets"]["break_glass_allowed"] == "authorised-only", maintenance

print("PASS hospital_live_safe_mode_json_contract_static")
