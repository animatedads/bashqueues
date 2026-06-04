#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
example = json.loads((root / "schemas/enterprise/profile_verify.example.json").read_text())
assert example["schema"] == "queuebash.enterprise_profile_verify.v1"
assert example["live_clearance_granted"] is False
assert example["system_modified"] is False
for profile in ["hospital-live-readonly-default", "hospital-live-approved-maintenance-default"]:
    out = subprocess.check_output([str(root / "providers.d/enterprise/enterprise_profile_verify.sh"), "--profile", profile, "--json"], text=True)
    data = json.loads(out)
    assert data["schema"] == "queuebash.enterprise_profile_verify.v1"
    assert data["profile"] == profile
    assert data["ok"] is True
    assert data["mode"] == "fixture-only"
    assert data["live_clearance_granted"] is False
    assert data["system_modified"] is False
    assert data["checks"]["policy_root_explicit"] is True
    assert data["checks"]["external_ai_disabled"] is True
print("PASS enterprise_profile_verify_json_contract_static")
