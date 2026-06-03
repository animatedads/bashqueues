#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="${QUEUEBASH_ROOT:-/tmp/queuebash-display-help-resource-smoke-root}"
rm -rf "$QUEUEBASH_ROOT"; mkdir -p "$QUEUEBASH_ROOT"

main_help="$(bash -lc 'source queuebash.sh; queue help')"
printf '%s\n' "$main_help" | grep -q 'queue submit <name>'
printf '%s\n' "$main_help" | grep -q 'Matching rules:'

resource_help="$(bash -lc 'source queuebash.sh; queue resource-fetch-i18nl --help')"
printf '%s\n' "$resource_help" | grep -q 'Usage: queue resource-fetch-i18nl'

dev_resource_help="$(bash -lc 'source queuebash.sh; queue dev resource --help')"
printf '%s\n' "$dev_resource_help" | grep -q 'Usage: queue dev resource extract'

# The runtime fallback directory is literally display/fallback, not lang_fallback.
printf 'Usage: fallback probe\n' >/tmp/queuebash-fallback-probe.txt
bash -lc 'source queuebash.sh; queue dev resource insert --dir /tmp/queuebash-resource-insert-fallback --name fallback-probe.txt --lang fallback --input /tmp/queuebash-fallback-probe.txt --json' | python3 -m json.tool >/dev/null
test -f /tmp/queuebash-resource-insert-fallback/display/fallback/fallback-probe.txt
