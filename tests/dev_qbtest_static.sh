#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

grep -q 'queue dev test qbtest --file FILE' resources.d/display/lang_eng/dev-qbtest-help.txt
grep -q 'queue dev test qbtest --file FILE' resources.d/display/fallback/dev-qbtest-help.txt
grep -q '_queue_dev_test_qbtest_command' queuebash.sh
grep -q 'queuebash.dev_qbtest_result.v1' queuebash.sh
grep -q 'QBTEST:BEGIN' docs/QUEUE_DEV_QBTEST.md
grep -q 'EXAMPLE_QBTEST:BEGIN' resources.d/display/lang_eng/dev-qbtest-help.txt
grep -q 'EXAMPLE_QBTEST:BEGIN' resources.d/display/fallback/dev-qbtest-help.txt
grep -q 'no_match' queuebash.sh
grep -q -- '--keep' docs/QUEUE_DEV_QBTEST.md
grep -q 'language=bash' docs/QUEUE_DEV_QBTEST.md
grep -q 'language=python' docs/QUEUE_DEV_QBTEST.md
grep -q -- '--h' queuebash.sh
grep -q 'did you mean --function' queuebash.sh
grep -q 'positional function name' docs/QUEUE_DEV_QBTEST.md

grep -q 'queue-dev-timeout' docs/QUEUE_DEV_TIMEOUT_HELPER.md
test -x bin/queue-dev-timeout
