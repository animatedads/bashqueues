#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
example = json.loads((root / "schemas/display_resource/resource_lint_result.example.json").read_text())
assert example["schema"] == "queuebash.display_resource_lint.v1"
assert example["status"] == "ok"
assert example["redacted"] is True
assert example["json_contract_source"] is False
assert example["secret_rendering_allowed"] is False
assert example["renderer"] == "none-lint-only"
assert example["findings"] == []

proc = subprocess.run(
    ["python3", "bin/queue-display-resource-lint.py", "--root", ".", "--json"],
    cwd=root,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    check=True,
)
payload = json.loads(proc.stdout)
assert payload["schema"] == "queuebash.display_resource_lint.v1"
assert payload["status"] == "ok", payload
assert payload["redacted"] is True
assert payload["json_contract_source"] is False
assert payload["secret_rendering_allowed"] is False
assert payload["renderer"] == "none-lint-only"
assert payload["stats"]["manifest_rows"] >= 2
assert payload["stats"]["resources_checked"] >= 2
assert payload["findings"] == []
print("PASS display_resource_lint_json_contract_static")
