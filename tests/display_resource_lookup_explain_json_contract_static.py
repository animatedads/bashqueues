#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
example = json.loads((root / "schemas/display_resource/resource_lookup_explain_result.example.json").read_text())
assert example["schema"] == "queuebash.display_resource_lookup_explain.v1"
assert example["status"] in {"ok", "error"}
assert example["redacted"] is True
assert example["owner_lane"] == "bob18-display-resources"
assert example["renderer"] == "none-lookup-explain-only"
assert example["source"] == "manifest-metadata-and-file-presence-only"
assert example["json_contract_source"] is False
assert example["secret_rendering_allowed"] is False
assert set(example["request"]) == {"type", "name", "language"}
assert set(example["resolution"]) == {"state", "selected_language", "selected_path", "fallback_used", "expected_paths"}
assert example["resolution"]["state"] in {"localized", "fallback", "missing"}
assert example["manifest"]["notes_redacted"] is True
for forbidden in ["rendering_templates", "token_replacement", "reading_secret_values", "json_generation_from_template"]:
    assert forbidden in example["forbidden"]
text = json.dumps(example).lower()
for bad in ["actual-secret", "secret-value", "private key", "akia"]:
    assert bad not in text
