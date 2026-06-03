#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

resources=(
  clean-logs-help.txt
  health-help.txt
  queue-dev-help.txt
  profile-interrogate-help.txt
)

for name in "${resources[@]}"; do
  for lang_dir in lang_eng fallback; do
    file="resources.d/display/$lang_dir/$name"
    test -f "$file" || { echo "missing wave3 display resource: $file" >&2; exit 1; }
    test -s "$file" || { echo "wave3 display resource is empty: $file" >&2; exit 1; }
  done
done

python3 - <<'PY'
from pathlib import Path
s = Path('queuebash.sh').read_text()
checks = {
    '_queue_clean_logs_usage': ('clean-logs-help.txt', 'queue clean-logs [options]'),
    '_queue_dev_usage': ('queue-dev-help.txt', 'queue dev functions [--file FILE]'),
    '_queue_health_report': ('health-help.txt', 'queue health [--fix]'),
    '_queue_profile_command': ('profile-interrogate-help.txt', 'queue profile interrogate run NAME'),
}
for func, (resource, old_text) in checks.items():
    start = s.index(func + '() {')
    end = s.find('\n}\n', start) + 3
    body = s[start:end]
    if resource not in body or '_queue_resource_fetch_i18nl_command' not in body:
        raise SystemExit(f'{func} does not dispatch through {resource}')
    if old_text in body:
        raise SystemExit(f'{func} still embeds old help text')
PY
