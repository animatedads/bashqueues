#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
export QUEUEBASH_ROOT="$root"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh
code="$(queue authorisation generate --admin root --user "$(id -un)" --code P44 --reason perms -- bash -lc 'echo perms' | awk '/authorisation:/ {print $2}')"
[[ "$code" == "P44" ]]
mode="$(stat -c '%a' "$root/authorisations/P44.env" 2>/dev/null || stat -f '%Lp' "$root/authorisations/P44.env")"
[[ "$mode" == "444" || "$mode" == "644" ]]
out="$(queue authorisation list)"
printf '%s\n' "$out"
grep -q '^P44 ' <<< "$out"
echo '[PASS] authorisation records are published readable instead of root-only'
