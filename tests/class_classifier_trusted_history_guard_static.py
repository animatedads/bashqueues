#!/usr/bin/env python3
"""Trusted-history guard checks for class-infer downgrade fixtures."""
import json
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
fixtures = root / "tests" / "fixtures" / "class_classifier"
cmd = [
    sys.executable,
    str(root / "bin" / "queue-class-infer.py"),
    "test",
    "--fixtures",
    str(fixtures),
    "--file",
    "jobs_trusted_history_guard.jsonl",
    "--json",
    "--include-case-results",
]
proc = subprocess.run(cmd, cwd=str(root), text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
obj = json.loads(proc.stdout)
assert obj["schema"] == "queuebash.class_classifier.test_result.v1"
assert obj["status"] == "pass", obj
assert obj["cases"] == 1, obj
assert obj["downgrade_detection"]["expected_blocks"] == 1, obj
assert obj["downgrade_detection"]["actual_blocks"] == 1, obj
assert obj["trusted_history_guard"]["excluded_rows_seen"] >= 2, obj
case = obj["case_results"][0]
assert case["recommended_class"] == "DB_EXPORT_HIGH_ASSURANCE", case
assert case["submitted_class"] == "BASIC_TASK", case
assert case["decision"] == "class_downgrade_suspected", case
assert case["recommended_action"] == "block_pending_authorisation", case
result = case["result"]
assert result["trusted_history"]["excluded_rows"] >= 2, result
assert result["trusted_history"]["excluded_reasons"].get("trusted_false", 0) >= 2, result
assert all("BASIC_TASK" not in reason or "dominant" not in reason for reason in result["reasons"]), result
print("class_classifier_trusted_history_guard_static: ok")
