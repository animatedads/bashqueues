#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

for file in \
  resources.d/display/lang_eng/queue-help.txt \
  resources.d/display/fallback/queue-help.txt \
  resources.d/display/lang_eng/resource-fetch-i18nl-help.txt \
  resources.d/display/fallback/resource-fetch-i18nl-help.txt \
  resources.d/display/lang_eng/dev-resource-help.txt \
  resources.d/display/fallback/dev-resource-help.txt; do
  test -f "$file" || { echo "missing help display resource: $file" >&2; exit 1; }
  grep -q 'Usage:' "$file" || { echo "help resource lacks Usage: $file" >&2; exit 1; }
done

# The main queue help function should be only a resource dispatcher now; the
# large help text belongs in resources.d/display, not in queuebash.sh.
help_body="$(awk '/^_queue_help\(\) \{/{flag=1} flag{print} flag && /^\}/{exit}' queuebash.sh)"
printf '%s\n' "$help_body" | grep -q 'queue-help.txt'
if printf '%s\n' "$help_body" | grep -q 'queue submit <name>'; then
  echo "_queue_help still embeds main help display text" >&2
  exit 1
fi

grep -q 'resource-fetch-i18nl-help.txt' queuebash.sh
grep -q 'dev-resource-help.txt' queuebash.sh
