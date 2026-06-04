#!/usr/bin/env python3
"""Static contract checks for queue class-infer test fixture runner."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
helper = (root / "bin" / "queue-class-infer.py").read_text(encoding="utf-8")

required = [
    'TEST_SCHEMA = "queuebash.class_classifier.test_result.v1"',
    'sub.add_parser("test"',
    'pt.add_argument("--fixtures", required=True)',
    'def run_fixture_tests(args: argparse.Namespace)',
    '"downgrade_detection"',
    '"false_positive_guard"',
    '"reason_coverage"',
    '"trusted_history_guard"',
    'def history_trust_summary(history: Iterable[Dict[str, Any]])',
    'trusted_history_row(row)',
    'jobs_trusted_history_guard.jsonl',
    '"non_mutating": True',
    'recommended_action") == "block_pending_authorisation"',
    'category == "near_miss"',
]
missing = [needle for needle in required if needle not in helper]
if missing:
    raise SystemExit("missing class-infer fixture test contract fragments: " + ", ".join(missing))

print("class_classifier_fixture_test_command_static: ok")
