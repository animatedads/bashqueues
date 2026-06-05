#!/usr/bin/env bash
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

grep -Eq 'QUEUEBASH_VERSION="0\.18\.[0-9]+"' queuebash.sh || fail "queuebash version shape missing"
grep -q 'queuebash.direct_execution_advice.v1' queuebash.sh || fail "direct execution JSON advice schema missing"
grep -q 'queuebash.command_catalog.v1' queuebash.sh || fail "global JSON command catalog schema missing"
grep -q 'QUEUEBASH_OUTPUT_JSON' queuebash.sh || fail "global JSON dynamic-scope switch missing"

set +e
bash queuebash.sh >/tmp/queuebash_direct_stdout.$$ 2>/tmp/queuebash_direct_stderr.$$
rc=$?
set -e
[[ "$rc" -eq 2 ]] || fail "direct execution should exit 2, got $rc"
grep -q 'Source it into bash instead:' /tmp/queuebash_direct_stderr.$$ || fail "direct execution advice missing source instruction"
grep -q 'source queuebash.sh' /tmp/queuebash_direct_stderr.$$ || fail "direct execution advice missing source command"

set +e
bash queuebash.sh --json >/tmp/queuebash_direct_json.$$ 2>/tmp/queuebash_direct_json_err.$$
rc=$?
set -e
[[ "$rc" -eq 2 ]] || fail "direct execution --json should exit 2, got $rc"
python3 - <<PY
import json, pathlib
obj=json.loads(pathlib.Path('/tmp/queuebash_direct_json.$$').read_text())
assert obj['schema'] == 'queuebash.direct_execution_advice.v1', obj
assert obj['reason'] == 'queuebash_must_be_sourced', obj
assert obj['source_command'].startswith('source '), obj
PY

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="/tmp/queuebash_bob28_json_root.$$"
rm -rf "$QUEUEBASH_ROOT"
# shellcheck source=/dev/null
source ./queuebash.sh
queue --json version >/tmp/queuebash_version_json.$$
python3 - <<PY
import json, pathlib
obj=json.loads(pathlib.Path('/tmp/queuebash_version_json.$$').read_text())
assert obj['schema'] == 'queuebash.version.v1', obj
assert obj['version'].startswith('0.18.'), obj
PY
queue version >/tmp/queuebash_version_text.$$
grep -Eq '^queuebash 0\.18\.[0-9]+$' /tmp/queuebash_version_text.$$ || fail "global JSON leaked into later human command"
queue --json help >/tmp/queuebash_help_json.$$
python3 - <<PY
import json, pathlib
obj=json.loads(pathlib.Path('/tmp/queuebash_help_json.$$').read_text())
assert obj['schema'] == 'queuebash.command_catalog.v1', obj
assert obj['global_json'] is True, obj
assert '--json' in obj['json_switches'], obj
assert 'submit' in obj['commands'], obj
assert 'remote-admin' in obj['commands'], obj
assert 'vcs' in obj['commands'], obj
assert 'dev' in obj['commands'], obj
PY
set +e
queue --json definitely-not-a-command >/tmp/queuebash_unknown_json.$$ 2>/tmp/queuebash_unknown_err.$$
rc=$?
set -e
[[ "$rc" -eq 2 ]] || fail "unknown global JSON command should exit 2, got $rc"
python3 - <<PY
import json, pathlib
obj=json.loads(pathlib.Path('/tmp/queuebash_unknown_json.$$').read_text())
assert obj['schema'] == 'queuebash.error.v1', obj
assert obj['code'] == 'unknown_command', obj
PY

rm -rf "$QUEUEBASH_ROOT"
rm -f /tmp/queuebash_direct_stdout.$$ /tmp/queuebash_direct_stderr.$$ /tmp/queuebash_direct_json.$$ /tmp/queuebash_direct_json_err.$$ \
      /tmp/queuebash_version_json.$$ /tmp/queuebash_version_text.$$ /tmp/queuebash_help_json.$$ /tmp/queuebash_unknown_json.$$ /tmp/queuebash_unknown_err.$$

echo "bob28 direct execution and global JSON static checks: OK"
