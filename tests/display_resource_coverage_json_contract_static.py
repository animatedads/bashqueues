#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
example = json.loads((root / "schemas/display_resource/resource_coverage_result.example.json").read_text())
assert example["schema"] == "queuebash.display_resource_coverage.v1"
assert example["redacted"] is True
assert example["renderer"] == "none-coverage-only"
assert example["source"] == "manifest-metadata-only"
assert example["json_contract_source"] is False
assert example["secret_rendering_allowed"] is False
assert "reading_secret_values" in example["forbidden"]
assert "provider_calls" in example["forbidden"]

out = subprocess.check_output(
    [sys.executable, str(root / "bin/queue-display-resource-coverage.py"), "--root", str(root), "--json"],
    text=True,
)
payload = json.loads(out)
assert payload["schema"] == "queuebash.display_resource_coverage.v1"
assert payload["status"] == "ok"
assert payload["redacted"] is True
assert payload["renderer"] == "none-coverage-only"
assert payload["source"] == "manifest-metadata-only"
assert payload["json_contract_source"] is False
assert payload["secret_rendering_allowed"] is False
assert payload["manifest_rows"] >= 5
assert payload["resource_count"] >= 3
assert payload["language_dirs"]["display"]
assert payload["resources"]
assert all(item["json_contract_source"] is False for item in payload["resources"])
assert all(item["secret_rendering_allowed"] is False for item in payload["resources"])
assert all(item["catalog_only"] is True for item in payload["resources"])
body = json.dumps(payload)
for forbidden in ("actual-secret", "secret-value", "BEGIN PRIVATE KEY", "AKIA"):
    assert forbidden not in body
print("PASS display_resource_coverage_json_contract_static")
