#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="${QUEUEBASH_ROOT:-$(mktemp -d)}"
# shellcheck disable=SC1091
source ./queuebash.sh >/dev/null
out="$(queue class-infer test --fixtures tests/fixtures/class_classifier --json)"
CLASS_INFER_TEST_JSON="$out" python3 - <<'PY'
import json, os
obj=json.loads(os.environ["CLASS_INFER_TEST_JSON"])
assert obj["schema"] == "queuebash.class_classifier.test_result.v1", obj
assert obj["status"] == "pass", obj
assert obj["failed"] == 0, obj
assert obj["downgrade_detection"]["actual_blocks"] == obj["downgrade_detection"]["expected_blocks"], obj
assert obj["false_positive_guard"]["unexpected_blocks"] == 0, obj
PY
printf 'class_classifier_fixture_test_command_smoke: ok\n'
