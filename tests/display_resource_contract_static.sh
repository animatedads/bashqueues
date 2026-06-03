#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for needle in '_queue_resource_fetch_i18nl_command' '_queue_dev_resource_command' '_queue_resource_validate_file' 'resource-fetch-i18nl' 'resources.d/display/*/*'; do
  grep -q "$needle" queuebash.sh || { echo "missing resource contract needle: $needle" >&2; exit 1; }
done
test -f docs/QUEUE_DISPLAY_RESOURCES.md
test -f resources.d/display/lang_eng/queue-version.txt
grep -q '{{VERSION}}' resources.d/display/lang_eng/queue-version.txt
grep -q 'queue code sign --all' docs/QUEUE_DISPLAY_RESOURCES.md
