#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail(){ echo "[FAIL] $*" >&2; exit 1; }

[[ -f assets.d/class_classifier.sh ]] || fail 'missing assets.d/class_classifier.sh'
bash -n assets.d/class_classifier.sh || fail 'class_classifier asset has bash syntax errors'

grep -q 'class_classifier:no_downgrade' assets.d/class_classifier.sh || fail 'no_downgrade facility missing'
grep -q 'class_classifier:warn_on_downgrade' assets.d/class_classifier.sh || fail 'warn_on_downgrade facility missing'
grep -q 'class_classifier:decision_explainable' assets.d/class_classifier.sh || fail 'decision_explainable facility missing'
grep -q 'decision_file=' assets.d/class_classifier.sh || fail 'decision_file contract missing'
grep -q 'job_file=' assets.d/class_classifier.sh || fail 'job_file preview contract missing'
grep -q 'unexplained_not_auto_blocked' assets.d/class_classifier.sh || fail 'unexplained non-auto-block guard missing'
grep -q 'non-mutating queue class-infer JSON decisions' assets.d/class_classifier.sh || fail 'non-mutating boundary comment missing'

grep -q 'queue_class_shared_asset class_classifier no_downgrade _' docs/QUEUE_CLASS_CLASSIFIER_TESTS.md || fail 'class policy no_downgrade example missing from docs'
grep -q 'decision_explainable' docs/QUEUE_CLASS_CLASSIFIER_TESTS.md || fail 'explainability asset doc missing'

if grep -q 'queue submit.*class_classifier\|_queue_submit_class_classifier\|auto-upclass' queuebash.sh; then
  fail 'submit-path integration found; asset must remain class-policy signal only'
fi

[[ ! -e assets.d/net_usage.sh ]] || fail 'assets.d/net_usage.sh must remain absent'

echo 'PASS class_classifier_asset_contract_static'
