#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
helper = root / "providers.d" / "cloud_broker" / "cloud_broker_provider.sh"
out = subprocess.check_output([
    str(helper), "explain", "--capability", "vm", "--profile", "gdpr-compute",
    "--provider", "aws", "--region", "eu-west-2", "--service", "compute",
    "--estimated-hourly-usd", "0.50", "--json"
], cwd=root, text=True)
obj = json.loads(out)
assert obj["schema"] == "queuebash.cloud_broker.explain.v1"
assert obj["policy_reference_mode"] == "local_policy_links_only"
refs = obj.get("policy_references", [])
ids = {r.get("id") for r in refs}
types = {r.get("type") for r in refs}
assert "gdpr-cross-border-screening" in ids
assert "corp-finops-standard" in ids
assert "regulatory" in types
assert "corporate" in types
assert all(r.get("uri") for r in refs)
assert obj.get("policy_reference_note")
