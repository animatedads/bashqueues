#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat >"$tmp/sample_qbtest.sh" <<'EOSH'
add_one() {
  printf '%s\n' "$(( ${1:-0} + 1 ))"
}
# QBTEST:BEGIN name=add-one-ok function=add_one language=bash
# QBTEST:B64
# b3V0PSIkKGFkZF9vbmUgNDEpIgpbWyAiJG91dCIgPT0gIjQyIiBdXQo=
# QBTEST:END
EOSH
cat >"$tmp/sample_qbtest.py" <<'EOPY'
def add(a, b):
    return a + b
# QBTEST:BEGIN name=add-ok function=add language=python
# QBTEST:B64
# YXNzZXJ0IHRhcmdldCg0MCwgMikgPT0gNDIKYXNzZXJ0IG1vZHVsZS5hZGQoMSwgMikgPT0gMwo=
# QBTEST:END
EOPY
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$tmp/root"
source ./queuebash.sh >/dev/null
bash_json="$(_queue_dev_test_qbtest_command --file "$tmp/sample_qbtest.sh" --json)"
python3 - "$bash_json" <<'PY'
import json,sys
d=json.loads(sys.argv[1])
assert d['schema']=='queuebash.dev_qbtest_result.v1'
assert d['status']=='pass'
assert d['counts']['pass']==1
PY
py_json="$(_queue_dev_test_qbtest_command --file "$tmp/sample_qbtest.py" --json)"
python3 - "$py_json" <<'PY'
import json,sys
d=json.loads(sys.argv[1])
assert d['schema']=='queuebash.dev_qbtest_result.v1'
assert d['status']=='pass'
assert d['results'][0]['language']=='python'
PY
list_json="$(_queue_dev_test_qbtest_command --file "$tmp/sample_qbtest.sh" --function add_one --list --json)"
python3 - "$list_json" <<'PY'
import json,sys
d=json.loads(sys.argv[1])
assert d['status']=='pass'
assert d['counts']['listed']==1
PY

help_out="$(_queue_dev_test_qbtest_command --h)"
grep -q 'queue dev test qbtest --file FILE' <<<"$help_out"
if _queue_dev_test_qbtest_command --file "$tmp/sample_qbtest.sh" add_one >"$tmp/pos.out" 2>"$tmp/pos.err"; then
  echo 'bare positional function filter should be rejected' >&2
  exit 1
fi
grep -q 'did you mean --function add_one' "$tmp/pos.err"

# Documentation/help examples must not be discovered as live tests.
set +e
no_match_json="$(_queue_dev_test_qbtest_command --file ./queuebash.sh --function my_func --json)"
no_match_rc=$?
set -e
[[ "$no_match_rc" -eq 3 ]]
python3 - "$no_match_json" <<'PY'
import json,sys
d=json.loads(sys.argv[1])
assert d['schema']=='queuebash.dev_qbtest_result.v1'
assert d['status']=='no_match'
assert d['count']==0
PY

now_json="$(_queue_dev_test_qbtest_command --file ./queuebash.sh --function _queue_now --json)"
python3 - "$now_json" <<'PY'
import json,sys
d=json.loads(sys.argv[1])
assert d['status']=='pass'
assert d['counts']['pass'] >= 1
assert all(r.get('function') == '_queue_now' for r in d['results'])
PY

echo "PASS dev_qbtest_smoke"
