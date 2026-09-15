#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for f in resources.d/display/lang_eng/platform-help.txt resources.d/display/fallback/platform-help.txt; do
  test -f "$f"
  grep -Fq 'Usage: queue platform [--json]' "$f"
  grep -Fq 'queuebash.platform_facts.v1' "$f"
done
if grep -n 'echo "Usage: queue platform' queuebash.sh >/tmp/platform_help_embed.$$ 2>/dev/null; then
  cat /tmp/platform_help_embed.$$ >&2
  rm -f /tmp/platform_help_embed.$$
  echo 'embedded queue platform help remains in queuebash.sh' >&2
  exit 1
fi
rm -f /tmp/platform_help_embed.$$ 2>/dev/null || true
grep -Fq '_queue_resource_fetch_i18nl_command --name platform-help.txt' queuebash.sh
