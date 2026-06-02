#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail(){ echo "[FAIL] $*" >&2; exit 1; }

for f in \
  docs/QUEUE_CLASS_INFERENCE.md \
  docs/QUEUE_CLASS_FINGERPRINTS.md \
  docs/QUEUE_CLASS_ANOMALY_POLICY.md \
  bin/queue-class-infer.py \
  policies.d/class-inference/default.json \
  tests/fixtures/class_inference/history.jsonl \
  tests/fixtures/class_inference/pins.jsonl; do
  [[ -f "$f" ]] || fail "missing $f"
done

grep -q 'queuebash.class_inference.fingerprint.v1' docs/QUEUE_CLASS_INFERENCE.md || fail 'fingerprint schema missing'
grep -q 'queuebash.class_inference.recommendation.v1' docs/QUEUE_CLASS_INFERENCE.md || fail 'recommendation schema missing'
grep -q 'queuebash.class_inference.policy.v1' docs/QUEUE_CLASS_INFERENCE.md || fail 'policy schema missing'
grep -q 'corporate_policy_refs' docs/QUEUE_CLASS_INFERENCE.md || fail 'corporate policy linkage missing'
grep -q 'regulatory_refs' docs/QUEUE_CLASS_INFERENCE.md || fail 'regulatory policy linkage missing'
grep -q 'mapped_pending_validation' docs/QUEUE_CLASS_INFERENCE.md || fail 'validation status missing'
grep -q 'queue class-infer' docs/QUEUE_CLASS_INFERENCE.md || fail 'command docs missing'
grep -q 'class-infer|class_infer|class-recommend|class-recommendation' queuebash.sh || fail 'dispatcher alias missing'
grep -q '_queue_class_infer_command' queuebash.sh || fail 'shell wrapper missing'

if grep -q 'queue submit.*class-infer\|_queue_submit_class_infer\|auto-upclass' queuebash.sh; then
  fail 'submit-path integration found in contract-only package'
fi

if grep -q 'curl\|gcloud\|aws \|oci \|az ' bin/queue-class-infer.py docs/QUEUE_CLASS_INFERENCE.md; then
  fail 'unexpected live provider command in class inference package'
fi

[[ ! -e assets.d/net_usage.sh ]] || fail 'assets.d/net_usage.sh must remain absent'
[[ -e caps.d/net_usage.sh ]] || fail 'caps.d/net_usage.sh must remain present'

echo 'PASS class_inference_contract_static'
