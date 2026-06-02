#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
helper = root / "providers.d" / "cloud_broker" / "cloud_broker_provider.sh"
res = subprocess.run([
    str(helper), "explain", "--capability", "vm", "--profile", "gdpr-compute",
    "--provider", "aws", "--region", "eu-west-2", "--service", "compute",
    "--estimated-hourly-usd", "0.50", "--json"
], cwd=root, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
obj = json.loads(res.stdout)
assert obj["schema"] == "queuebash.cloud_broker.explain.v1"
assert obj["decision"] == "review"
assert obj["capability"] == "vm"
assert obj["profile"] == "gdpr-compute"
assert obj["non_mutating"] is True
assert obj["live_api_calls"] is False
assert obj["dispatch_binding"] is False
assert isinstance(obj.get("components"), dict)
assert "cloud_signals" in obj["components"]
assert "cloud_resource" in obj["components"]
assert "cloud_provision" in obj["components"]
assert "cloud_infra" in obj["components"]

assert obj.get("policy_reference_mode") == "local_policy_links_only"
refs = obj.get("policy_references", [])
assert isinstance(refs, list) and refs, "broker explain should include applicable policy references"
assert any(r.get("type") == "regulatory" for r in refs), refs
assert any(r.get("type") == "corporate" for r in refs), refs
assert any(r.get("uri", "").startswith("policy://") for r in refs), refs
cs = obj["components"].get("cloud_signals") or {}
assert cs.get("policy_references"), "cloud_signals explain should propagate policy references"
