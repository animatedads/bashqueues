#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
text = (root / "docs" / "ACL_PROVIDER_CONTRACT.md").read_text()
assert "queuebash.acl_decision.v1" in text
assert "job.submit" in text
assert "ai.context.queue_status" in text
assert "ai.context.job_metadata" in text
assert "allow" in text and "deny" in text and "error" in text
assert "fail closed" in text.lower()
assert "never shell" in text.lower()

sample = {
    "schema": "queuebash.acl_decision.v1",
    "provider": "file_acl",
    "subject": "hc3",
    "operation": "job.submit",
    "resource": "class:LEGAL_COMPLIANCE",
    "decision": "allow",
    "reason": "subject is in configured submitters group",
    "evidence": [{"type": "group", "value": "cn=bashqueues-submitters,ou=groups,dc=example,dc=com"}],
    "ttl_seconds": 300,
    "cache_policy": "positive-ttl",
    "fail_closed": True,
}
encoded = json.dumps(sample)
decoded = json.loads(encoded)
assert decoded["schema"] == "queuebash.acl_decision.v1"
assert decoded["decision"] in {"allow", "deny", "error"}
assert isinstance(decoded["evidence"], list)
assert isinstance(decoded["ttl_seconds"], int)
assert decoded["fail_closed"] is True
print(f"PASS {Path(__file__).name}")
