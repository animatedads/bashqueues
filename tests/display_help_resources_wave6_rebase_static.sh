#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

resources=(
  overdir-help.txt
  overfiles-help.txt
  status-help.txt
  tail-help.txt
)
for name in "${resources[@]}"; do
  test -f "resources.d/display/lang_eng/$name"
  test -f "resources.d/display/fallback/$name"
  cmp -s "resources.d/display/lang_eng/$name" "resources.d/display/fallback/$name"
  grep -Fq 'Usage:' "resources.d/display/lang_eng/$name"
  grep -Fq -- "--name $name" queuebash.sh
done

if grep -n "cat <<'EOF'" queuebash.sh | grep -E '(^36:|^126:|^6531:|^21362:)' >/dev/null; then
  echo "wave6 help heredoc remains at an extracted location" >&2
  exit 1
fi

for literal in \
  'Runs the command once for each matching directory.' \
  'Runs the command once for each matching file.' \
  'Compact machine/operator summary' \
  'running job: show last 40 lines, then follow'
do
  if grep -Fq "$literal" queuebash.sh; then
    echo "extracted help prose remains embedded in queuebash.sh: $literal" >&2
    exit 1
  fi
done
