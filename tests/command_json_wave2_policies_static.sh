#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

bash -n queuebash.sh

grep -q 'queuebash.policies.list.v1' queuebash.sh
grep -q '_queue_policy_list_json' queuebash.sh
grep -q 'queue policies list \[sandbox|seccomp|class-statement\] \[--json\]' queuebash.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$tmp/root"
# shellcheck disable=SC1091
source "$ROOT/queuebash.sh"

queue policies list --json > "$tmp/policies.json"
python3 - "$tmp/policies.json" <<'PYJSON'
import json, sys
p=sys.argv[1]
data=json.load(open(p, encoding='utf-8'))
assert data['schema'] == 'queuebash.policies.list.v1'
assert data['queue_root']
assert data['shared_root'].endswith('/policies.d')
assert data['personal_root'].endswith('/policies.d')
assert isinstance(data['kinds'], list) and 'sandbox' in data['kinds']
assert isinstance(data['policies'], list)
assert isinstance(data['count'], int)
for item in data['policies']:
    assert item['kind'] in ('sandbox','seccomp','class-statement')
    assert item['name']
    assert item['origin'] in ('source','personal','shared','unknown')
    assert item['path']
    assert item['sha256']
PYJSON

queue policies list sandbox --json > "$tmp/sandbox.json"
python3 - "$tmp/sandbox.json" <<'PYJSON'
import json, sys
data=json.load(open(sys.argv[1], encoding='utf-8'))
assert data['schema'] == 'queuebash.policies.list.v1'
assert data['kinds'] == ['sandbox']
assert all(item['kind'] == 'sandbox' for item in data['policies'])
PYJSON

queue policies --json > "$tmp/default.json"
python3 - "$tmp/default.json" <<'PYJSON'
import json, sys
data=json.load(open(sys.argv[1], encoding='utf-8'))
assert data['schema'] == 'queuebash.policies.list.v1'
PYJSON
