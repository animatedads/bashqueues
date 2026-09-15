#!/usr/bin/env bash
set -euo pipefail
fail() { echo "FAIL: $*" >&2; exit 1; }
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

version="$(sed -n 's/^QUEUEBASH_VERSION="\([^"]*\)".*/\1/p' queuebash.sh | head -1)"
[[ "$version" =~ ^0\.18\.[0-9]+$ ]] || fail "unexpected QUEUEBASH_VERSION: ${version:-missing}"
grep -q 'queuebash.command_catalog.v1' queuebash.sh || fail "command catalog schema missing"
for cmd in health events policies policy pids metrics hooks cancel delete pause unpause priority clear restore resubmit clean-logs compress-logs backup reevaluate platform workers tail show run rto governance catalog; do
  grep -q '"'"$cmd"'"' queuebash.sh || fail "command catalog missing $cmd"
done
