#!/usr/bin/env bash
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

grep -q '0.18.125 BOB28 user selector JSON hardening' README.md || fail "README entry missing"
grep -q '0.18.125 BOB28 user selector JSON hardening' CHANGELOG.md || fail "CHANGELOG entry missing"
grep -q 'missing_user' queuebash.sh || fail "missing user JSON error code missing"
grep -q 'no_such_user' queuebash.sh || fail "no such user JSON error code missing"

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="/tmp/queuebash_bob28_selector_root.$$"
initial_queuebash_root="$QUEUEBASH_ROOT"
rm -rf "$initial_queuebash_root"
# shellcheck source=/dev/null
source ./queuebash.sh

set +e
queue --json user >/tmp/queuebash_selector_missing.$$ 2>/tmp/queuebash_selector_missing_err.$$
rc=$?
set -e
[[ "$rc" -eq 2 ]] || fail "queue --json user should exit 2, got $rc"
python3 - <<PY
import json, pathlib
obj=json.loads(pathlib.Path('/tmp/queuebash_selector_missing.$$').read_text())
assert obj['schema'] == 'queuebash.error.v1', obj
assert obj['code'] == 'missing_user', obj
assert 'queue user USER' in obj['usage'], obj
PY
set +e
queue --json --queue-user __queuebash_no_such_user_zzzz__ >/tmp/queuebash_selector_no_user.$$ 2>/tmp/queuebash_selector_no_user_err.$$
rc=$?
set -e
[[ "$rc" -eq 2 ]] || fail "queue --json --queue-user missing user should exit 2, got $rc"
python3 - <<PY
import json, pathlib
obj=json.loads(pathlib.Path('/tmp/queuebash_selector_no_user.$$').read_text())
assert obj['schema'] == 'queuebash.error.v1', obj
assert obj['code'] == 'no_such_user', obj
PY
current_user="$(id -un)"
queue --json user "$current_user" >/tmp/queuebash_selector_current.$$
python3 - <<PY
import json, pathlib
obj=json.loads(pathlib.Path('/tmp/queuebash_selector_current.$$').read_text())
assert obj['schema'] == 'queuebash.selected_user.v1', obj
assert obj['selected_user'], obj
assert obj['queue_root'].endswith('/.queuebash'), obj
PY

rm -rf "$initial_queuebash_root"
rm -f /tmp/queuebash_selector_missing.$$ /tmp/queuebash_selector_missing_err.$$ \
      /tmp/queuebash_selector_no_user.$$ /tmp/queuebash_selector_no_user_err.$$ \
      /tmp/queuebash_selector_current.$$

echo "bob28 user selector JSON static checks: OK"
