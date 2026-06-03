#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

resources=(
  cleared-help.txt
  key-provider-help.txt
  acl-help.txt
  module-help.txt
  module-provider-help.txt
  cloud-help.txt
  profile-signature-help.txt
  ai-help.txt
  system-daemon-help.txt
  sentinel-help.txt
)

for name in "${resources[@]}"; do
  for lang_dir in lang_eng fallback; do
    file="resources.d/display/$lang_dir/$name"
    test -f "$file" || { echo "missing wave2 display resource: $file" >&2; exit 1; }
    test -s "$file" || { echo "wave2 display resource is empty: $file" >&2; exit 1; }
  done
done

python3 - <<'PY'
from pathlib import Path
s = Path('queuebash.sh').read_text()
checks = {
    '_queue_cleared_jobs_list': 'queue cleared [--json]',
    '_queue_key_provider_help': 'queue key-provider help',
    '_queue_acl_command_help': 'queue acl - enterprise ACL/provider decision contract',
    '_queue_cloud_command_help': 'queue cloud - unified cloud broker front',
    '_queue_profile_multisig_help': 'queue profile-signature help',
}
for func, old_text in checks.items():
    start = s.index(func + '() {')
    end = s.find('\n}\n', start) + 3
    body = s[start:end]
    if 'resource_fetch_i18nl_command' not in body:
        raise SystemExit(f'{func} does not dispatch through display resources')
    if old_text in body:
        raise SystemExit(f'{func} still embeds display text')
for resource in ['cleared-help.txt','module-help.txt','module-provider-help.txt','ai-help.txt','system-daemon-help.txt','sentinel-help.txt']:
    if resource not in s:
        raise SystemExit(f'{resource} is not referenced by queuebash.sh')
PY
