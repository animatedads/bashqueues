#!/usr/bin/env python3
import json
import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
PROVIDER = ROOT / "providers.d" / "cloud_provision" / "cloud_provision.sh"
POLICY = ROOT / "policies.d" / "cloud-provision" / "approval-policy.example.json"

policy = json.loads(POLICY.read_text())
assert policy["schema"] == "queuebash.cloud_provision.approval_policy.v1"
assert "approval" in policy["rules"]
assert "live_gate" in policy["rules"]
assert policy["rules"]["live_gate"]["provider_credentials_are_not_authority"] is True
assert policy["rules"]["live_gate"]["live_apply_implemented"] is False

approval = subprocess.check_output([
    str(PROVIDER), "approval-request", "aws-ec2-gdpr",
    "--change-ticket", "CHG-12345",
    "--reason", "approved customer database migration window",
    "--authority", "data-owner",
    "--audit-sink", "jsonl",
    "--data-protection-review",
    "--json",
], text=True)
approval_doc = json.loads(approval)
assert approval_doc["schema"] == "queuebash.cloud_provision.approval_gate.v1"
assert approval_doc["decision"] == "allow"
assert approval_doc["mutated"] is False
assert approval_doc["live"] is False

with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
    json.dump(approval_doc, f)
    approval_path = f.name
try:
    live = subprocess.check_output([
        str(PROVIDER), "live-gate", "aws-ec2-gdpr",
        "--approval", approval_path,
        "--live-enabled",
        "--json",
    ], text=True)
finally:
    pathlib.Path(approval_path).unlink(missing_ok=True)
live_doc = json.loads(live)
assert live_doc["schema"] == "queuebash.cloud_provision.live_gate.v1"
assert live_doc["decision"] == "review"
assert live_doc["reason"] == "contract_only_no_live_apply_implemented"
assert live_doc["live_apply_available"] is False
assert live_doc["queue_dispatch_path"] is False
assert live_doc["mutated"] is False
assert live_doc["cloud_mutation"] is False
print("PASS cloud_provision_approval_live_gate_json_contract_static")
