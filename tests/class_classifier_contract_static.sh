#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail(){ echo "[FAIL] $*" >&2; exit 1; }

for f in \
  docs/QUEUE_CLASS_CLASSIFIER_TESTS.md \
  bin/queue-class-infer.py \
  tests/fixtures/class_classifier/history_normal.jsonl \
  tests/fixtures/class_classifier/jobs_normal.jsonl \
  tests/fixtures/class_classifier/jobs_downgrade.jsonl \
  tests/fixtures/class_classifier/jobs_near_miss.jsonl \
  tests/fixtures/class_classifier/jobs_cold_start.jsonl \
  tests/fixtures/class_classifier/jobs_adversarial_rename.jsonl \
  tests/fixtures/class_classifier/jobs_drift.jsonl \
  tests/fixtures/class_classifier/policy_block_on_downgrade.json; do
  [[ -f "$f" ]] || fail "missing $f"
done

grep -q -- '--job' bin/queue-class-infer.py || fail 'class-infer --job support missing'
grep -q 'trusted_history_row' bin/queue-class-infer.py || fail 'trusted-history guard missing'
grep -q 'class_downgrade_suspected' bin/queue-class-infer.py || fail 'downgrade decision missing'
grep -q 'block_pending_authorisation' bin/queue-class-infer.py || fail 'authorisation block recommendation missing'
grep -q 'defer_to_class_policy' bin/queue-class-infer.py || fail 'cold-start defer action missing'
grep -q 'reasons' bin/queue-class-infer.py || fail 'explainability reasons missing'
grep -q 'not as a direct submit-path policy override' docs/QUEUE_CLASS_CLASSIFIER_TESTS.md || fail 'submit boundary doc missing'
grep -q 'must not automatically block' docs/QUEUE_CLASS_CLASSIFIER_TESTS.md || fail 'explainability safety doc missing'

if grep -q 'queue submit.*class-infer\|_queue_submit_class_infer\|auto-upclass' queuebash.sh; then
  fail 'submit-path integration found; classifier should remain policy signal only'
fi

[[ ! -e assets.d/net_usage.sh ]] || fail 'assets.d/net_usage.sh must remain absent'

echo 'PASS class_classifier_contract_static'
