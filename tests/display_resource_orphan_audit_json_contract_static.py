#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
example = json.loads((root / "schemas/display_resource/resource_orphan_audit_result.example.json").read_text())
assert example["schema"] == "queuebash.display_resource_orphan_audit.v1"
assert example["read_only"] is True
assert example["renderer"] == "none-orphan-audit-only"
assert example["source"] == "manifest-rows-and-resource-file-presence-only"
assert example["file_content_read"] is False
assert example["signing_mutation"] is False
assert example["permission_mutation"] is False
assert example["secret_rendering_allowed"] is False
assert example["json_contract_source"] is False
assert example["token_value_substitution"] is False
for key in ("manifest_entries", "discovered_resource_files", "orphan_resource_files", "missing_manifest_resources", "duplicate_manifest_entries", "findings"):
    assert isinstance(example[key], list), key

proc = subprocess.run(
    [sys.executable, str(root / "bin/queue-display-resource-orphan-audit.py"), "--root", str(root), "--json"],
    check=True,
    text=True,
    stdout=subprocess.PIPE,
)
payload = json.loads(proc.stdout)
assert payload["schema"] == "queuebash.display_resource_orphan_audit.v1"
assert payload["status"] in {"ok", "warning"}
assert payload["read_only"] is True
assert payload["file_content_read"] is False
assert payload["stats"]["manifest_entries"] >= 1
