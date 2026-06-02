#!/usr/bin/env python3
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent
protocol = (root / "docs" / "QUEUE_API_PROTOCOL.md").read_text(encoding="utf-8")
embedded = (root / "docs" / "QUEUE_API_EMBEDDED.md").read_text(encoding="utf-8")

required_terms = [
    "queuebash.api.request.v1",
    "queuebash.api.response.v1",
    "invalid_json",
    "unknown_operation",
    "operation_denied",
    "session.create",
    "session.list",
]
for term in required_terms:
    if term not in protocol:
        raise SystemExit(f"missing protocol term: {term}")

examples = re.findall(r"```json\n(.*?)\n```", protocol, flags=re.S)
if len(examples) < 4:
    raise SystemExit("expected at least four JSON examples in protocol docs")

for idx, raw in enumerate(examples, 1):
    try:
        json.loads(raw)
    except Exception as exc:
        raise SystemExit(f"json example {idx} is invalid: {exc}")

if "queuebash.api.request.v1" not in embedded or "queuebash.api.denied.v1" not in embedded:
    raise SystemExit("embedded docs missing audit event schemas")

print("queue_api_protocol_json_contract_static: ok")
