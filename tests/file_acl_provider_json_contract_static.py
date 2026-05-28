#!/usr/bin/env python3
import json
import subprocess
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
text = (root / "docs" / "ACL_PROVIDER_CONTRACT.md").read_text()
assert "queuebash.acl_decision.v1" in text
assert "QUEUEBASH_ACL_PROVIDER=file" in text
assert "QUEUEBASH_FILE_ACL_POLICY" in text
assert "file_acl_policy_malformed" in text
assert "no_matching_file_acl_rule" in text
assert "providers never supply shell" in text.lower() or "Providers supply normalized data, never shell" in text

sample_allow = {
    "schema": "queuebash.acl_decision.v1",
    "provider": "file",
    "decision": "allow",
    "subject": "hc3",
    "operation": "job.submit",
    "resource": "*",
    "reason": "local user may submit jobs",
    "evidence": [{"type": "file_acl", "policy_file": "/home/hc3/.queuebash/policy/acl/file_acl.tsv", "line": 2}],
    "ttl_seconds": 0,
    "fail_closed": False,
}
encoded = json.dumps(sample_allow)
decoded = json.loads(encoded)
assert decoded["schema"] == "queuebash.acl_decision.v1"
assert decoded["provider"] == "file"
assert decoded["decision"] == "allow"
assert decoded["fail_closed"] is False
assert decoded["evidence"][0]["line"] == 2

sample_error = dict(sample_allow, decision="error", reason="file_acl_policy_malformed", fail_closed=True)
assert sample_error["decision"] == "error"
assert sample_error["fail_closed"] is True
print(f"PASS {Path(__file__).name}")
