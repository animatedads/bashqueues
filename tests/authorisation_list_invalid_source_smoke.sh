#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export QUEUEBASH_ROOT="$TMP"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh

mkdir -p "$TMP/authorisations"
printf 'AUTHORISATION_CODE=%s\nthis is not valid shell\n' 'JQ9ST' > "$TMP/authorisations/JQ9ST.env"
printf 'not even close\n' > "$TMP/authorisations/OAN25.env"

out="$(queue authorisation list)"
printf '%s\n' "$out"

grep -q '^JQ9ST .*status=invalid-source .*integrity=invalid-source' <<< "$out"
grep -q '^OAN25 .*status=invalid-source .*integrity=invalid-source' <<< "$out"
if grep -q "\\$'\\\\t'" <<< "$out"; then
    echo "FAIL: literal shell-escaped tab marker leaked into authorisation list output" >&2
    exit 1
fi

echo "[PASS] invalid authorisation source rows list cleanly"
