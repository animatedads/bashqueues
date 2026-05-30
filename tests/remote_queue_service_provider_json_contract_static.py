#!/usr/bin/env python3
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
doc = (root / "docs" / "REMOTE_QUEUE_SERVICE_PROVIDER.md").read_text(encoding="utf-8")
blocks = re.findall(r"```json\n(.*?)\n```", doc, flags=re.S)
if len(blocks) < 6:
    raise SystemExit("[FAIL] expected at least six JSON contract examples")

seen_service_allow = False
seen_service_deny = False
seen_result = False
seen_policy_request = False
seen_policy_response = False

for block in blocks:
    obj = json.loads(block)
    schema = obj.get("schema")
    if schema == "queuebash.remote_queue_service.v1":
        if obj.get("provider") != "remote-queue":
            raise SystemExit("[FAIL] service example missing provider remote-queue")
        if obj.get("decision") not in {"allow", "deny", "error"}:
            raise SystemExit("[FAIL] service example has invalid decision")
        if obj.get("decision") == "allow":
            seen_service_allow = True
        if obj.get("decision") == "deny":
            seen_service_deny = True
            if "safe_message" not in obj:
                raise SystemExit("[FAIL] denial example missing safe_message")
        if obj.get("status") == "ok" and "exit_code" in obj:
            seen_result = True
            if not isinstance(obj.get("duration_ms"), int):
                raise SystemExit("[FAIL] duration_ms must be int")
            for key in ("stdout_tail", "stderr_tail"):
                if key not in obj or not isinstance(obj[key], str):
                    raise SystemExit("[FAIL] bounded log tail missing or not string")
    elif schema == "queuebash.remote_queue_policy_request.v1":
        seen_policy_request = True
        if not obj.get("operation") or not obj.get("subject"):
            raise SystemExit("[FAIL] policy request missing operation/subject")
        if not isinstance(obj.get("requested_args"), list):
            raise SystemExit("[FAIL] policy request requested_args must be list")
    elif schema == "queuebash.remote_queue_policy_response.v1":
        seen_policy_response = True
        if obj.get("decision") not in {"allow", "deny", "error"}:
            raise SystemExit("[FAIL] policy response invalid decision")
        for key in ("max_runtime_seconds", "max_stdout_bytes", "max_stderr_bytes"):
            if key in obj and not isinstance(obj[key], int):
                raise SystemExit("[FAIL] policy response numeric limit must be int")
    else:
        raise SystemExit("[FAIL] unexpected JSON schema %r" % (schema,))

if not seen_service_allow:
    raise SystemExit("[FAIL] no service allow example found")
if not seen_service_deny:
    raise SystemExit("[FAIL] no service deny example found")
if not seen_result:
    raise SystemExit("[FAIL] no bounded execution result example found")
if not seen_policy_request:
    raise SystemExit("[FAIL] no policy request example found")
if not seen_policy_response:
    raise SystemExit("[FAIL] no policy response example found")

print("[PASS] remote queue service provider JSON examples parse and validate")
