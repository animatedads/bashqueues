#!/usr/bin/env python3
"""Static guard for scratchpad authority object shape.

The scratchpad CLI expects each ledger item authority to be an object. Historical
merge notes once used a plain string or a role-only object, which broke
next/list/export with AttributeError or missing fields. Keep this guard narrow
and data-focused so future scratchpad corpus imports fail clearly before
packaging.
"""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
pad = root / ".queuebash" / "dev" / "scratchpad.json"
data = json.loads(pad.read_text(encoding="utf-8"))
items = data.get("items", [])
assert isinstance(items, list), "scratchpad items must be a list"
for idx, item in enumerate(items):
    assert isinstance(item, dict), f"item {idx} is not an object"
    authority = item.get("authority")
    item_id = item.get("id", f"index-{idx}")
    assert isinstance(authority, dict), f"{item_id}: authority must be an object, not {type(authority).__name__}"
    for key in ("type", "name", "confidence"):
        assert authority.get(key), f"{item_id}: authority.{key} missing"
    assert isinstance(item.get("provenance", {}), dict), f"{item_id}: provenance must be an object"
print("PASS dev_scratchpad_authority_shape_static")
