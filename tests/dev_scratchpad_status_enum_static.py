#!/usr/bin/env python3
"""Static guard for scratchpad item status values.

The scratchpad working-set commands assume every item has a string status from
its documented enum. Historical merge imports once leaked null statuses into
`queue dev scratchpad next --json`; this guard prevents that from recurring.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRATCHPAD = ROOT / ".queuebash" / "dev" / "scratchpad.json"
ALLOWED = {
    "active",
    "pending",
    "done",
    "rejected",
    "stale",
    "proposed",
    "blocked",
    "removed",
}

data = json.loads(SCRATCHPAD.read_text(encoding="utf-8"))
assert data.get("schema") == "queuebash.dev_scratchpad.v1"
items = data.get("items")
assert isinstance(items, list) and items, "scratchpad items missing"
for index, item in enumerate(items):
    item_id = item.get("id", f"<index:{index}>")
    status = item.get("status")
    assert isinstance(status, str), f"scratchpad item {item_id} has non-string status {status!r}"
    assert status in ALLOWED, f"scratchpad item {item_id} has invalid status {status!r}"
print("PASS dev_scratchpad_status_enum_static")
