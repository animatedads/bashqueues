#!/usr/bin/env python3
"""Static/source contract for class-infer fixture decision metrics."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
helper = (root / "bin" / "queue-class-infer.py").read_text(encoding="utf-8")
docs = (root / "docs" / "QUEUE_CLASS_CLASSIFIER_TESTS.md").read_text(encoding="utf-8")

required_helper_terms = [
    '"decision_metrics"',
    '"downgrade_detection_rate"',
    '"near_miss_false_positive_rate"',
    '"cold_start_unknown_rate"',
    '"risk_floor_escalation_rate"',
    '"reason_coverage_rate"',
    '"per_category"',
    '"metrics are derived from hard fixture expectations',
]
for term in required_helper_terms:
    assert term in helper, f"missing helper metrics term: {term}"

required_doc_terms = [
    'decision_metrics',
    'downgrade_detection_rate',
    'near_miss_false_positive_rate',
    'cold_start_unknown_rate',
    'reason_coverage_rate',
    'metrics are observability signals',
]
for term in required_doc_terms:
    assert term in docs, f"missing docs metrics term: {term}"

assert 'auto-upclass' not in helper
assert 'queue submit' not in helper or 'Submit-path enforcement is intentionally out of scope' in helper

print('PASS class_classifier_fixture_metrics_static')
