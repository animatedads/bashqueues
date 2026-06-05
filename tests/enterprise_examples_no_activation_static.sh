#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

for sh in "$repo_root"/examples/enterprise/*.sh; do
  [[ -f "$sh" ]] || continue
  bash -n "$sh"
  if grep -E '\b(cp|mv|install)\b.*/etc/queuebash|\btee\b.*/etc/queuebash|enable-profile|activate-profile|live_clearance_granted[=:]true|system_modified[=:]true' "$sh" >/dev/null; then
    echo "unsafe activation/mutation wording in $(basename "$sh")" >&2
    exit 1
  fi
  grep -q 'queue enterprise' "$sh" || { echo "missing queue enterprise call in $(basename "$sh")" >&2; exit 1; }
 done

python3 - <<'PY' "$repo_root/examples/enterprise/maintenance-request.example.json"
import json, sys
p = sys.argv[1]
with open(p, 'r', encoding='utf-8') as fh:
    data = json.load(fh)
assert data.get('schema') == 'queuebash.enterprise.maintenance_request.v1'
assert data.get('live_clearance_requested') is False
for key in ('request_id', 'environment', 'profile', 'ticket', 'approver', 'rollback', 'audit_log'):
    assert data.get(key), f'missing {key}'
print('PASS maintenance_request_example_json')
PY

echo "PASS enterprise_examples_no_activation_static"
