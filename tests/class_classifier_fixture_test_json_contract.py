#!/usr/bin/env python3
"""JSON contract check for queue class-infer test --fixtures."""
import json
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
cmd = [
    sys.executable,
    str(root / "bin" / "queue-class-infer.py"),
    "test",
    "--fixtures",
    str(root / "tests" / "fixtures" / "class_classifier"),
    "--json",
]
proc = subprocess.run(cmd, cwd=str(root), text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
obj = json.loads(proc.stdout)

assert obj["schema"] == "queuebash.class_classifier.test_result.v1"
assert obj["status"] == "pass", obj
assert obj["cases"] == 9, obj
assert obj["passed"] == obj["cases"]
assert obj["failed"] == 0
assert obj["downgrade_detection"]["expected_blocks"] == 4
assert obj["downgrade_detection"]["actual_blocks"] == 4
assert obj["false_positive_guard"]["near_miss_cases"] == 1
assert obj["false_positive_guard"]["unexpected_blocks"] == 0
assert obj["reason_coverage"]["cases_requiring_reasons"] >= 4
assert obj["reason_coverage"]["cases_with_reasons"] == obj["reason_coverage"]["cases_requiring_reasons"]
assert obj["trusted_history_guard"]["excluded_rows_seen"] >= 5
assert obj["trusted_history_guard"]["trusted_rows_seen"] >= obj["cases"]
assert obj["trusted_history_guard"].get("reviewed_rows_seen", 0) >= 3
assert obj["risk_floor_guard"]["cases"] >= 1
assert obj["risk_floor_guard"]["escalations"] >= 1
metrics = obj.get("decision_metrics")
assert isinstance(metrics, dict), obj
assert metrics["downgrade_detection_rate"] == 1.0, metrics
assert metrics["near_miss_false_positive_rate"] == 0.0, metrics
assert metrics["cold_start_unknown_rate"] == 1.0, metrics
assert metrics["reason_coverage_rate"] == 1.0, metrics
assert metrics["decision_counts"]["class_downgrade_suspected"] == 4, metrics
assert metrics["recommended_action_counts"]["block_pending_authorisation"] == 4, metrics
assert metrics["recommended_action_counts"]["allow"] >= 3, metrics
assert metrics["recommendation_source_counts"]["history"] >= 7, metrics
assert metrics["per_category"]["near_miss"]["cases"] == 1, metrics
assert metrics["per_category"]["near_miss"]["failed"] == 0, metrics
assert metrics["per_category"]["cold_start"]["cases"] == 1, metrics
assert metrics["per_category"]["drift"]["cases"] == 2, metrics
assert any("not a replacement for pass/fail" in note for note in metrics.get("notes", [])), metrics
assert obj["non_mutating"] is True

cases = obj["case_results"]
assert {c["category"] for c in cases} >= {"normal", "downgrade", "near_miss", "cold_start", "adversarial_rename", "drift", "trusted_history_guard", "reviewed_history_guard"}
for case in cases:
    assert case["status"] == "pass", case
    assert "decision" in case and "recommended_action" in case and "reason_count" in case, case
    assert "trusted_history" in case, case
    assert "risk_floor" in case, case

print(f"class_classifier_fixture_test_json_contract: cases={obj['cases']}")
