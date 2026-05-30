#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
source ./queuebash.sh >/dev/null
json_get_string(){ sed -n "s/.*\"$2\":\"\([^\"]*\)\".*/\1/p" "$1" | head -n 1; }
assert_contains(){ local file="$1" text="$2"; grep -Fq "$text" "$file" || { echo "missing $text in $file" >&2; cat "$file" >&2; exit 1; }; }
work="$(mktemp -d)"

# Bounded smoke for the class and result path. Deeper pass/fail/timeout semantics
# are covered by the JSON/static contracts; this smoke avoids chaining multiple
# isolated harness queues into one long-running test.
echo SMOKE pass >&2
queue dev test --run --timeout 3 --json -- bash -c 'echo PASS' >"$work/pass.json"
assert_contains "$work/pass.json" '"schema":"queuebash.dev_test_result.v1"'
assert_contains "$work/pass.json" '"status":"pass"'
assert_contains "$work/pass.json" '"exit_code":0'
assert_contains "$work/pass.json" '"done":1'
job_id="$(json_get_string "$work/pass.json" job_id)"
hroot="$(json_get_string "$work/pass.json" harness_root)"
[[ -n "$job_id" && -n "$hroot" ]] || { echo "failed to extract job_id/harness_root" >&2; cat "$work/pass.json" >&2; exit 1; }

echo SMOKE result >&2
queue dev test result "$job_id" --root "$hroot" --json >"$work/result.json"
assert_contains "$work/result.json" '"status":"pass"'

echo SMOKE submit >&2
queue dev test --json -- bash -c 'echo PASS' >"$work/submit.json"
assert_contains "$work/submit.json" '"status":"submitted"'
assert_contains "$work/submit.json" '"class":"DEV_TEST_RUNNER"'
assert_contains "$work/submit.json" '"pending":1'

echo 'PASS dev_test_runner_class_smoke'
