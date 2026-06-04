#!/usr/bin/env python3
import json
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
helper = root / "bin" / "queue-class-infer.py"
fixtures = root / "tests" / "fixtures" / "class_classifier"
policy = fixtures / "policy_block_on_downgrade.json"
history = fixtures / "history_normal.jsonl"

high_risk_cold_start = {
    "job_name": "new_backup_with_prod_secret",
    "command": "bash /opt/jobs/new_backup.sh --prod-db-sync",
    "submitted_class": "BASIC_TASK",
    "user": "backup",
    "paths": ["/backups", "/data/customer"],
    "secrets": ["customer-db/prod/password"],
    "assets": ["db:customer-prod", "net:allowance"],
    "network": True,
}
low_risk_cold_start = {
    "job_name": "new_report_builder",
    "command": "python3 ./new_report.py --input /tmp/example.csv",
    "submitted_class": "BASIC_TASK",
    "user": "analyst",
    "paths": ["/tmp/example.csv"],
    "secrets": [],
    "network": False,
}

def run(job):
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", suffix=".json") as tmp:
        json.dump(job, tmp)
        tmp.flush()
        out = subprocess.check_output([
            sys.executable, str(helper), "recommend", "--json",
            "--history", str(history), "--policy", str(policy), "--job", tmp.name,
        ], cwd=root, text=True)
    return json.loads(out)

hi = run(high_risk_cold_start)
assert hi["decision"] == "risk_floor_escalation", hi
assert hi["recommended_action"] == "require_authorisation", hi
assert hi["recommended_class"] == "HIGH_ASSURANCE_REVIEW", hi
assert hi["risk_floor"]["applies"] is True, hi
assert hi["risk_floor"]["score"] >= hi["risk_floor"]["threshold"], hi
assert hi["reasons"], hi
assert hi["non_mutating"] is True, hi

lo = run(low_risk_cold_start)
assert lo["decision"] == "insufficient_history", lo
assert lo["recommended_action"] == "defer_to_class_policy", lo
assert lo["risk_floor"]["applies"] is False, lo

print("class_classifier_risk_floor_static: ok")
