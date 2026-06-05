#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "FAIL: $*" >&2; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

bash -n queuebash.sh || fail "queuebash.sh syntax failed"
grep -q 'BOB28 top-level option order hardening' README.md || fail "README entry missing"
grep -q 'BOB28 top-level option order hardening' CHANGELOG.md || fail "CHANGELOG entry missing"
grep -q 'while \[\[ "\$#" -gt 0 \]\]' queuebash.sh || fail "top-level option parsing loop missing"
grep -q 'queue --dryrun --json help' queuebash.sh || fail "documented dryrun/json order example missing"

out="$(QUEUEBASH_ALLOW_NONINTERACTIVE=1 bash -c 'source ./queuebash.sh; queue --dryrun --json help')"
python3 - "$out" <<'PY' || fail "queue --dryrun --json help did not emit command catalog JSON"
import json, sys
obj=json.loads(sys.argv[1])
assert obj['schema'] == 'queuebash.command_catalog.v1', obj
assert obj['global_json'] is True, obj
PY

out="$(QUEUEBASH_ALLOW_NONINTERACTIVE=1 bash -c 'source ./queuebash.sh; queue -n -j version')"
python3 - "$out" <<'PY' || fail "queue -n -j version did not emit version JSON"
import json, sys
obj=json.loads(sys.argv[1])
assert obj['schema'] == 'queuebash.version.v1', obj
assert obj['version'].startswith('0.18.'), obj
PY

echo "bob28 top-level option order static checks: OK"
