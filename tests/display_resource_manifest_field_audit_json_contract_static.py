#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
helper = root / "bin" / "queue-display-resource-manifest-field-audit.py"
proc = subprocess.run([sys.executable, str(helper), "--root", str(root), "--json"], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
if proc.returncode != 0:
    raise SystemExit(f"helper failed rc={proc.returncode}\nSTDOUT={proc.stdout}\nSTDERR={proc.stderr}")
data = json.loads(proc.stdout)
assert data["schema"] == "queuebash.display_resource_manifest_field_audit.v1"
assert data["status"] == "ok", data
for key in ["manifest_only"]:
    assert data[key] is True, key
for key in [
    "resource_body_read",
    "resource_rendering",
    "token_substitution",
    "secret_rendering",
    "provider_calls",
    "signing_mutation",
    "install_mutation",
    "permission_mutation",
    "json_contract_source",
]:
    assert data[key] is False, key
summary = data["summary"]
assert summary["entries"] >= 1
assert summary["audited_entries"] == summary["entries"]
assert summary["errors"] == 0, data["findings"]
assert isinstance(data["entries"], list)
assert isinstance(data["findings"], list)
assert all("field_contract_ok" in entry for entry in data["entries"])
print("display_resource_manifest_field_audit_json_contract_static: ok")
