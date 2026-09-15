#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="${TMPDIR:-/tmp}/queuebash-wave16-smoke-$$"
rm -rf "$QUEUEBASH_ROOT"
# shellcheck disable=SC1091
source ./queuebash.sh
out="$(queue platform --help)"
case "$out" in
  *'Usage: queue platform [--json]'* ) ;;
  *) echo "missing platform usage in help" >&2; printf '%s
' "$out" >&2; exit 1 ;;
esac
case "$out" in
  *'queuebash.platform_facts.v1'* ) ;;
  *) echo "missing platform JSON contract hint" >&2; printf '%s
' "$out" >&2; exit 1 ;;
esac
json="$(queue platform --json)"
case "$json" in
  *'"schema":"queuebash.platform_facts.v1"'* ) ;;
  *) echo "platform json contract regressed" >&2; printf '%s
' "$json" >&2; exit 1 ;;
esac
rm -rf "$QUEUEBASH_ROOT"
