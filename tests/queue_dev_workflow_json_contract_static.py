#!/usr/bin/env python3
"""Static JSON example checks for proposed queue dev workflow commands.

This test deliberately avoids invoking `queue dev`.  The 0.18.43 package is a
contract/docs/static-tests package only, and previous review sandboxes proved
that dispatcher/init probes can hang.  Validate the proposed machine-readable
examples and doc references instead.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path.cwd()
if not (ROOT / "queuebash.sh").exists():
    print("FAIL: run from repository root", file=sys.stderr)
    sys.exit(1)

SCHEMA_DIR = ROOT / "schemas" / "dev_workflow"
DOCS = [
    ROOT / "docs" / "QUEUE_DEV_WORKFLOW_COMMANDS.md",
    ROOT / "docs" / "QUEUE_DEV_WORKFLOW_SCHEMAS.md",
]

EXPECTED = {
    "context.example.json": ("queuebash.dev_workflow.context.v1", {"schema", "status", "mode", "filters", "items", "warnings"}),
    "think.example.json": ("queuebash.dev_workflow.think.v1", {"schema", "status", "item_id", "kind", "authority", "text_hash", "tags"}),
    "attempt_begin.example.json": ("queuebash.dev_workflow.attempt.v1", {"schema", "status", "attempt_id", "phase", "authority"}),
    "attempt_end.example.json": ("queuebash.dev_workflow.attempt.v1", {"schema", "status", "attempt_id", "phase", "authority"}),
    "evidence_record.example.json": ("queuebash.dev_workflow.evidence.v1", {"schema", "status", "evidence_id", "attempt_id", "result"}),
    "handover.example.json": ("queuebash.dev_workflow.handover.v1", {"schema", "status", "mode", "base_version", "deliveries", "open_tasks", "known_landmines", "next"}),
    "scratchpad_status.example.json": ("queuebash.dev_workflow.scratchpad_status.v1", {"schema", "status", "item_id", "old_status", "new_status"}),
    "supersede.example.json": ("queuebash.dev_workflow.supersede.v1", {"schema", "status", "item_id", "superseded_by"}),
}


def fail(msg: str) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)
    sys.exit(1)

if not SCHEMA_DIR.is_dir():
    fail("missing schemas/dev_workflow")

doc_text = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in DOCS)

for filename, (schema_name, required_keys) in EXPECTED.items():
    path = SCHEMA_DIR / filename
    if not path.exists():
        fail(f"missing {path}")
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"invalid JSON in {filename}: {exc}")
    if not isinstance(payload, dict):
        fail(f"{filename} did not decode to object")
    if payload.get("schema") != schema_name:
        fail(f"{filename} schema mismatch: {payload.get('schema')!r}")
    missing = sorted(required_keys - set(payload))
    if missing:
        fail(f"{filename} missing keys: {', '.join(missing)}")
    if payload.get("status") != "ok":
        fail(f"{filename} should use ok success example")
    if schema_name not in doc_text:
        fail(f"docs do not mention {schema_name}")
    json.loads(json.dumps(payload, sort_keys=True))

status_doc = (ROOT / "docs" / "QUEUE_DEV_WORKFLOW_COMMANDS.md").read_text(encoding="utf-8", errors="replace")
for status in ["active", "in_progress", "blocked", "superseded", "resolved", "accepted", "rejected", "failed"]:
    if status not in status_doc:
        fail(f"status vocabulary missing {status}")

print("PASS queue_dev_workflow_json_contract_static")
