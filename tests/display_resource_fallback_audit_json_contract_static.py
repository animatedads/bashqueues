#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
schema = json.loads((root / "schemas/display_resource/resource_fallback_audit_result.example.json").read_text())
assert schema["schema"] == "queuebash.display_resource_fallback_audit.v1"
assert schema["redacted"] is True
assert schema["renderer"] == "none-fallback-audit-only"
assert schema["source"] == "manifest-metadata-and-file-presence-only"
assert schema["json_contract_source"] is False
assert schema["secret_rendering_allowed"] is False
assert schema["token_value_substitution"] is False
assert "resources" in schema and isinstance(schema["resources"], list)
assert "findings" in schema and isinstance(schema["findings"], list)

proc = subprocess.run(
    [sys.executable, str(root / "bin/queue-display-resource-fallback-audit.py"), "--root", str(root), "--json"],
    check=True,
    text=True,
    stdout=subprocess.PIPE,
)
payload = json.loads(proc.stdout)
assert payload["schema"] == schema["schema"]
assert payload["status"] == "ok", payload.get("findings")
assert payload["redacted"] is True
assert payload["stats"]["fallback_required_resources"] >= 1
assert payload["stats"]["fallback_present_resources"] == payload["stats"]["fallback_required_resources"]
assert all(item["json_contract_source"] is False for item in payload["resources"])
assert all(item["secret_rendering_allowed"] is False for item in payload["resources"])
text = json.dumps(payload, sort_keys=True).lower()
for forbidden in ["actual-secret", "secret-value", "begin rsa private key", "akia"]:
    assert forbidden not in text
