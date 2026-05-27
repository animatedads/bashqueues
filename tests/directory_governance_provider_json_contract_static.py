#!/usr/bin/env python3
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
doc = (root / "docs" / "DIRECTORY_GOVERNANCE_PROVIDERS.md").read_text(encoding="utf-8")
blocks = re.findall(r"```json\n(.*?)\n```", doc, flags=re.S)
if len(blocks) < 6:
    raise SystemExit("[FAIL] expected at least six JSON contract examples")

seen = {
    "ldap_acl": False,
    "ldap_policy": False,
    "ldap_key": False,
    "pam_account": False,
    "pam_identity": False,
    "pam_acl": False,
}

for block in blocks:
    obj = json.loads(block)
    if obj.get("schema") != "queuebash.provider.v1":
        raise SystemExit("[FAIL] JSON example missing schema queuebash.provider.v1")
    if obj.get("provider") not in {"ldap", "pam"}:
        raise SystemExit("[FAIL] JSON example has unexpected provider")
    if obj.get("decision") not in {"allow", "deny", "error"}:
        raise SystemExit("[FAIL] JSON example has invalid decision")
    if "ttl_seconds" in obj and not isinstance(obj["ttl_seconds"], int):
        raise SystemExit("[FAIL] ttl_seconds must be an integer when present")
    if "operation" in obj and not re.match(r"^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$", obj["operation"]):
        raise SystemExit("[FAIL] invalid operation format")
    if "required_assets" in obj:
        seen["ldap_policy"] = obj.get("provider") == "ldap"
        for asset in obj["required_assets"]:
            if not re.match(r"^[A-Za-z0-9_:-]+$", asset.get("asset", "")):
                raise SystemExit("[FAIL] invalid asset name in required_assets")
            if not re.match(r"^[A-Za-z0-9_:-]+$", asset.get("facility", "")):
                raise SystemExit("[FAIL] invalid facility name in required_assets")
            if not isinstance(asset.get("args"), list) or not all(isinstance(x, str) for x in asset["args"]):
                raise SystemExit("[FAIL] required_assets args must be list[str]")
    if obj.get("provider") == "ldap" and obj.get("operation") == "profile.approve":
        seen["ldap_acl"] = True
    if obj.get("provider") == "ldap" and obj.get("purpose") == "profile-public-key":
        seen["ldap_key"] = True
    if obj.get("provider") == "pam" and obj.get("operation") == "job.submit":
        seen["pam_account"] = True
    if obj.get("provider") == "pam" and obj.get("uid") == 1001:
        seen["pam_identity"] = True
    if obj.get("provider") == "pam" and obj.get("operation") == "dev.patch":
        seen["pam_acl"] = True

missing = [name for name, ok in seen.items() if not ok]
if missing:
    raise SystemExit("[FAIL] missing JSON examples: " + ", ".join(missing))

print("[PASS] Directory governance provider JSON examples parse and validate")
