#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
example = json.loads((root / "schemas/display_resource/resource_encoding_audit_result.example.json").read_text())
assert example["schema"] == "queuebash.display_resource_encoding_audit.v1"
assert example["read_only"] is True
assert example["renderer"] == "none-encoding-audit-only"
assert example["source"] == "manifest-listed-resource-bytes-for-encoding-only"
assert example["file_content_read_scope"] == "manifest-listed-display-xml-resource-bytes-only"
assert example["resource_rendering"] is False
assert example["signing_mutation"] is False
assert example["permission_mutation"] is False
assert example["secret_rendering_allowed"] is False
assert example["json_contract_source"] is False
assert example["token_value_substitution"] is False
for key in ("resources", "findings", "forbidden"):
    assert isinstance(example[key], list), key
for key in ("utf8_invalid", "nul_byte_resources", "unsafe_control_resources", "crlf_resources", "mixed_line_ending_resources"):
    assert key in example["stats"], key

proc = subprocess.run(
    [sys.executable, str(root / "bin/queue-display-resource-encoding-audit.py"), "--root", str(root), "--json"],
    check=True,
    text=True,
    stdout=subprocess.PIPE,
)
payload = json.loads(proc.stdout)
assert payload["schema"] == "queuebash.display_resource_encoding_audit.v1"
assert payload["status"] in {"ok", "warning"}
assert payload["read_only"] is True
assert payload["resource_rendering"] is False
assert payload["stats"]["manifest_entries"] >= 1
assert isinstance(payload["resources"], list)
