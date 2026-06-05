#!/usr/bin/env bash
set -euo pipefail
fail() { echo "FAIL: $*" >&2; exit 1; }
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

grep -q 'QUEUEBASH_VERSION="0.18.125"' queuebash.sh || fail "version not advanced to 0.18.125"
grep -q 'queuebash.command_catalog.v1' queuebash.sh || fail "command catalog schema missing"
for cmd in health events policies pids metrics hooks cancel delete pause unpause priority clear restore resubmit clean-logs compress-logs backup reevaluate; do
  grep -q "\"$cmd\"" queuebash.sh || fail "command catalog missing $cmd"
done

echo "command catalog JSON discoverability static checks: OK"
