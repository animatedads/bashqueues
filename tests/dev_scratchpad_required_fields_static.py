#!/usr/bin/env python3
"""Guard scratchpad corpus item shape for queue dev scratchpad consumers.

The scratchpad command can tolerate older imported notes, but the curated corpus
must not drift back into partial item shapes.  Every item should expose the
minimum fields documented by the scratchpad contract so next/list/export callers
can consume a consistent object without null-field special cases.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAD = ROOT / ".queuebash" / "dev" / "scratchpad.json"
VALID_STATUSES = {"active", "pending", "done", "rejected", "stale", "proposed", "blocked", "removed"}

obj = json.loads(PAD.read_text(encoding="utf-8"))
items = obj.get("items")
assert isinstance(items, list), "scratchpad items must be a list"

for idx, item in enumerate(items):
    prefix = f"item[{idx}] {item.get('id', '<no-id>')}"
    assert item.get("schema") == "queuebash.dev_scratchpad_item.v1", f"{prefix}: schema missing/wrong"
    assert isinstance(item.get("id"), str) and item["id"], f"{prefix}: id missing"
    assert isinstance(item.get("kind"), str) and item["kind"], f"{prefix}: kind missing"
    assert isinstance(item.get("status"), str), f"{prefix}: status must be string"
    assert item["status"] in VALID_STATUSES, f"{prefix}: invalid status {item['status']!r}"
    assert isinstance(item.get("tags"), list), f"{prefix}: tags must be list"
    assert isinstance(item.get("text"), str), f"{prefix}: text must be string"
    assert isinstance(item.get("created_at"), str) and item["created_at"], f"{prefix}: created_at missing"
    assert isinstance(item.get("updated_at"), str) and item["updated_at"], f"{prefix}: updated_at missing"

    authority = item.get("authority")
    assert isinstance(authority, dict), f"{prefix}: authority must be object"
    for field in ("type", "name", "source", "confidence"):
        assert isinstance(authority.get(field), str) and authority[field], f"{prefix}: authority.{field} missing"

    counters = item.get("counters")
    assert isinstance(counters, dict), f"{prefix}: counters must be object"
    assert isinstance(counters.get("success"), int), f"{prefix}: counters.success must be int"
    assert isinstance(counters.get("failure"), int), f"{prefix}: counters.failure must be int"

    provenance = item.get("provenance")
    assert isinstance(provenance, dict), f"{prefix}: provenance must be object"
    for field in ("source_type", "source_ref"):
        assert isinstance(provenance.get(field), str) and provenance[field], f"{prefix}: provenance.{field} missing"

print("PASS dev_scratchpad_required_fields_static")
