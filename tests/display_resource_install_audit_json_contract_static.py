#!/usr/bin/env python3
import json
from pathlib import Path

schema = json.loads(Path("schemas/display_resource/resource_install_audit_result.example.json").read_text())
assert schema["schema"] == "queuebash.display_resource_install_audit.v1"
assert schema["status"] == "ok"
assert schema["redacted"] is True
assert schema["read_only"] is True
assert schema["installer"] is False
assert schema["signing_mutation"] is False
assert schema["renderer"] == "none-install-audit-only"
assert schema["source"] == "manifest-metadata-and-file-hash-presence-only"
assert schema["json_contract_source"] is False
assert schema["secret_rendering_allowed"] is False
assert schema["token_value_substitution"] is False
assert "secret_values" in schema["forbidden"]
assert "resource_rendering" in schema["forbidden"]
assert "command_json_generation_from_templates" in schema["forbidden"]
assert isinstance(schema["resources"], list)
assert isinstance(schema["findings"], list)
