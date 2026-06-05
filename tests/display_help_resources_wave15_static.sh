#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for f in \
  resources.d/display/lang_eng/platform-help.txt \
  resources.d/display/fallback/platform-help.txt
  do
    [[ -s "$f" ]] || { echo "missing resource: $f" >&2; exit 1; }
    grep -Fq 'Usage: queue platform [--json]' "$f"
  done
if grep -n 'Emits local runtime/platform facts. Windows support claim is WSL2-first.' queuebash.sh >/dev/null; then
  echo 'platform help prose still embedded in queuebash.sh' >&2
  exit 1
fi
grep -Fq '_queue_resource_fetch_i18nl_command --name platform-help.txt' queuebash.sh
