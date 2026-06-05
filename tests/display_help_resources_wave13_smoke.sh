#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
export QUEUEBASH_ROOT="$root"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
# shellcheck disable=SC1091
source ./queuebash.sh >/dev/null 2>&1
out="$(queue vcs help)"
printf '%s\n' "$out" | grep -Fq 'Usage: queue vcs detect [PATH] [--json]'
printf '%s\n' "$out" | grep -Fq 'Read-only VCS tenant diagnostics'
out2="$(queue vcs detect --help)"
printf '%s\n' "$out2" | grep -Fq 'Usage: queue vcs detect [PATH] [--json]'
types="$(queue vcs types)"
printf '%s\n' "$types" | grep -Fxq git
printf '%s\n' "$types" | grep -Fxq svn
