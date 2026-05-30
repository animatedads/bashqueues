#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "FAIL $*" >&2; exit 1; }

grep -Eq 'QUEUEBASH_VERSION="0\.18\.(4[0-9]|[5-9][0-9])"' queuebash.sh || fail 'queuebash version not current enough for dev test runner compatibility'
grep -Eq 'WIZARD_VERSION="0\.[0-9]+\.[0-9]+"' bin/queue-policy-wizard || fail 'wizard version string missing/malformed'
grep -q '^## 0.18.25 internal dev test runner class' README.md || fail 'README release section missing'
grep -q '^## 0.18.25 - internal dev test runner class' CHANGELOG.md || fail 'CHANGELOG release section missing'
[[ -f classes/DEV_TEST_RUNNER.env ]] || fail 'DEV_TEST_RUNNER class missing'
[[ -f docs/DEV_TEST_RUNNER.md ]] || fail 'DEV_TEST_RUNNER docs missing'
grep -q 'queue dev test \[--run\]' queuebash.sh || fail 'dev test usage missing'
grep -q 'test) _queue_dev_test_command' queuebash.sh || fail 'dev test dispatch missing'
grep -q 'queuebash.dev_test_result.v1' queuebash.sh || fail 'result schema missing'
grep -q '_queue_dev_test_command()' queuebash.sh || fail 'dev test command function missing'
grep -q '_queue_dev_test_counts_json()' queuebash.sh || fail 'state counts helper missing'
grep -q '_queue_dev_test_result_json()' queuebash.sh || fail 'result helper missing'
grep -q 'queue submit .*--class DEV_TEST_RUNNER' queuebash.sh || fail 'normal submit route missing'
grep -q 'scratchpad) _queue_dev_scratchpad_command' queuebash.sh || fail 'scratchpad dispatch not preserved'
! [[ -e assets.d/net_usage.sh ]] || fail 'assets.d/net_usage.sh must remain absent'
echo 'PASS dev_test_runner_class_static'
