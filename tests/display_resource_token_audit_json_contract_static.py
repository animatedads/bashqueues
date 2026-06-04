#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
proc = subprocess.run(
    [sys.executable, str(root / "bin" / "queue-display-resource-token-audit.py"), "--root", str(root), "--json"],
    check=True,
    text=True,
    capture_output=True,
)
payload = json.loads(proc.stdout)
assert payload["schema"] == "queuebash.display_resource_token_audit.v1"
assert payload["status"] == "ok"
assert payload["redacted"] is True
assert payload["renderer"] == "none-token-audit-only"
assert payload["source"] == "manifest-and-resource-token-names-only"
assert payload["json_contract_source"] is False
assert payload["secret_rendering_allowed"] is False
assert payload["token_value_substitution"] is False
assert payload["stats"]["resources_checked"] >= 4
assert payload["stats"]["undeclared_used_tokens"] == 0
for entry in payload["resources"]:
    assert isinstance(entry["declared_tokens"], list)
    assert isinstance(entry["used_tokens"], list)
    assert entry["undeclared_tokens"] == []
    assert entry["secret_token_names_present"] is False
print("PASS display_resource_token_audit_json_contract_static")
