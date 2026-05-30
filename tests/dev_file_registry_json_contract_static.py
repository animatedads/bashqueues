#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
for rel, schema in [
    ("schemas/dev_workflow/file_registry.example.json", "queuebash.dev_file_registry.v1"),
    ("schemas/dev_workflow/patchset.example.json", "queuebash.dev_patchset.v1"),
]:
    data = json.loads((root / rel).read_text())
    assert data["schema"] == schema
    assert isinstance(data.get("entries"), list) and data["entries"]
reg = json.loads((root / "schemas/dev_workflow/file_registry.example.json").read_text())
entry = reg["entries"][0]
assert "baseline" in entry and "current" in entry
assert "md5" in entry["baseline"] and "md5" in entry["current"]
assert entry["changed_functions"][0]["old_md5"]
assert entry["changed_functions"][0]["new_md5"]
patch = json.loads((root / "schemas/dev_workflow/patchset.example.json").read_text())
pentry = patch["entries"][0]
assert pentry["file"].startswith("files/")
assert pentry["diff"].startswith("diffs/")
assert pentry["changed_functions"][0]["old_md5"]
print("PASS dev_file_registry_json_contract_static")
