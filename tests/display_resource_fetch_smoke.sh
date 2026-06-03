#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="${QUEUEBASH_ROOT:-/tmp/queuebash-display-resource-smoke-root}"
rm -rf "$QUEUEBASH_ROOT"; mkdir -p "$QUEUEBASH_ROOT"
source queuebash.sh
out="$(_queue_resource_fetch_i18nl_command --name queue-version.txt --lang lang_es --var VERSION=TEST)"
[[ "$out" == 'Bashqueue versión TEST' ]]
out="$(_queue_resource_fetch_i18nl_command --name queue-version.txt --lang lang_catilanian --var VERSION=TEST)"
[[ "$out" == 'Bashqueue versión TEST' ]]
json="$(_queue_resource_fetch_i18nl_command --name queue-version.txt --lang lang_ar --var VERSION=TEST --json)"
printf '%s\n' "$json" | python3 -m json.tool >/dev/null
printf '%s\n' "$json" | grep -q 'إصدار Bashqueue رقم TEST'
printf 'bad ${VERSION}\n' > /tmp/queuebash-bad-resource.txt
if _queue_resource_validate_file /tmp/queuebash-bad-resource.txt >/tmp/queuebash-bad-resource.out 2>&1; then
  echo "unsafe resource unexpectedly passed validation" >&2
  exit 1
fi
