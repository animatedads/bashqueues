#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail(){ echo "[FAIL] $*" >&2; exit 1; }
canonical_root='/etc/queuebash'
canonical_policy='/etc/queuebash/policies.d/remote-queue'
legacy_root='/etc/bashqueues'
helper='providers.d/remote_admin/remote_admin_policy.py'

python3 -m py_compile "$helper" || fail 'remote-admin policy helper does not compile'
grep -q 'DEFAULT_ROOT = "/etc/queuebash"' "$helper" || fail 'remote-admin default root is not canonical /etc/queuebash'
! grep -q 'DEFAULT_ROOT = "/etc/bashqueues"' "$helper" || fail 'remote-admin default root still uses legacy /etc/bashqueues'
grep -q 'default=DEFAULT_ROOT' "$helper" || fail 'remote-admin argparse no longer uses DEFAULT_ROOT'

json="$(providers.d/remote_admin/remote_admin_policy.sh --actor nobody@example.invalid --json validate || true)"
python3 - "$json" "$canonical_policy" "$legacy_root" <<'PY' || exit 1
import json, sys
obj=json.loads(sys.argv[1])
canonical=sys.argv[2]
legacy=sys.argv[3]
assert obj.get('schema') == 'queuebash.remote_admin.response.v1', obj
assert obj.get('status') == 'denied', obj
assert obj.get('resource') == '*', obj
# A default-root validate without --root must attempt ACL/audit under the canonical tree.
# It is denied because no live ACL exists in the test container, but it must not mention
# or depend on the legacy root.
text=json.dumps(obj, sort_keys=True)
assert legacy not in text, text
PY

grep -q "$canonical_policy" tests/fixtures/remote_admin/clients.tsv || fail 'remote-admin fixture client secret path not canonical'

printf '[PASS] remote-admin policy helper default namespace is canonical\n'
