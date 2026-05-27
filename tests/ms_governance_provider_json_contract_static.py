#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
doc = (root / "docs" / "MS_GOVERNANCE_PROVIDER.md").read_text(encoding="utf-8")
blocks = re.findall(r"```json\n(.*?)\n```", doc, flags=re.S)
if len(blocks) < 4:
    raise SystemExit("[FAIL] expected at least four JSON contract examples")

seen_required_assets = False
seen_acl = False
seen_key = False
for block in blocks:
    obj = json.loads(block)
    if obj.get("schema") != "queuebash.provider.v1":
        raise SystemExit("[FAIL] JSON example missing schema queuebash.provider.v1")
    if obj.get("provider") != "microsoft":
        raise SystemExit("[FAIL] JSON example missing provider microsoft")
    if obj.get("decision") not in {"allow", "deny", "error"}:
        raise SystemExit("[FAIL] JSON example has invalid decision")
    if "ttl_seconds" in obj and not isinstance(obj["ttl_seconds"], int):
        raise SystemExit("[FAIL] ttl_seconds must be an integer when present")
    if "required_assets" in obj:
        seen_required_assets = True
        for asset in obj["required_assets"]:
            if not re.match(r"^[A-Za-z0-9_:-]+$", asset.get("asset", "")):
                raise SystemExit("[FAIL] invalid asset name in required_assets")
            if not re.match(r"^[A-Za-z0-9_:-]+$", asset.get("facility", "")):
                raise SystemExit("[FAIL] invalid facility name in required_assets")
            if not isinstance(asset.get("args"), list) or not all(isinstance(x, str) for x in asset["args"]):
                raise SystemExit("[FAIL] required_assets args must be list[str]")
    if obj.get("operation") == "profile.approve":
        seen_acl = True
    if obj.get("purpose") == "profile-public-key":
        seen_key = True

if not seen_required_assets:
    raise SystemExit("[FAIL] no required_assets example found")
if not seen_acl:
    raise SystemExit("[FAIL] no profile.approve ACL example found")
if not seen_key:
    raise SystemExit("[FAIL] no key resolver example found")

print("[PASS] Microsoft governance provider JSON examples parse and validate")
