#!/usr/bin/env python3
import json
from pathlib import Path

schema_path = Path("schemas/display_resource/resource_permission_audit_result.example.json")
payload = json.loads(schema_path.read_text())
assert payload["schema"] == "queuebash.display_resource_permission_audit.v1"
assert payload["status"] in {"ok", "error"}
assert payload["redacted"] is True
assert payload["owner_lane"] == "bob18-display-resources"
assert payload["renderer"] == "none-permission-audit-only"
assert payload["source"] == "manifest-metadata-and-filesystem-mode-only"
assert payload["read_only"] is True
assert payload["installer"] is False
assert payload["signing_mutation"] is False
assert payload["permission_mutation"] is False
assert payload["json_contract_source"] is False
assert payload["secret_rendering_allowed"] is False
assert payload["token_value_substitution"] is False
required = payload["required_file_properties"]
assert required["regular_file"] is True
assert required["symlink_allowed"] is False
assert required["executable_allowed"] is False
assert required["group_writable_allowed"] is False
assert required["world_writable_allowed"] is False
assert required["owner_readable_required"] is True
for key in [
    "manifest_files_checked",
    "resource_files_checked",
    "files_checked",
    "findings",
    "executable_files",
    "group_writable_files",
    "world_writable_files",
    "symlink_files",
]:
    assert key in payload["stats"]
assert isinstance(payload["files"], list)
assert isinstance(payload["findings"], list)
assert "chmod_mutation" in payload["forbidden"]
assert "secret_values" in payload["forbidden"]
assert "command_json_generation_from_templates" in payload["forbidden"]
serialised = json.dumps(payload).lower()
assert "actual-secret" not in serialised
assert "secret-value" not in serialised
