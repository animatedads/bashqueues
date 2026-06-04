#!/usr/bin/env python3
"""Regression for reviewed-only trusted history mode."""
import json
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
fixtures = root / "tests" / "fixtures" / "class_classifier"
helper = root / "bin" / "queue-class-infer.py"
job = fixtures / "jobs_reviewed_history_guard.jsonl"

row = json.loads(job.read_text(encoding="utf-8").splitlines()[0])
tmp = root / "tests" / "fixtures" / "class_classifier" / "decisions" / ".reviewed_history_guard_job.tmp.json"
try:
    tmp.write_text(json.dumps(row), encoding="utf-8")
    out = subprocess.check_output([
        sys.executable, str(helper), "recommend", "--json",
        "--history", str(fixtures / "history_unreviewed_labels.jsonl"),
        "--policy", str(fixtures / "policy_reviewed_history_only.json"),
        "--job", str(tmp),
    ], cwd=root, text=True)
finally:
    tmp.unlink(missing_ok=True)

obj = json.loads(out)
assert obj["decision"] == "class_downgrade_suspected", obj
assert obj["recommended_action"] == "block_pending_authorisation", obj
assert obj["recommended_class"] == "DB_EXPORT_HIGH_ASSURANCE", obj
trust = obj["trusted_history"]
assert trust["trust_mode"] == "reviewed_only", trust
assert trust["excluded_rows"] == 3, trust
assert trust["excluded_reasons"].get("missing_review_marker") == 3, trust
assert trust["reviewed_rows"] >= 3, trust
assert obj["reasons"], obj
print("class_classifier_reviewed_history_guard_static: ok")
