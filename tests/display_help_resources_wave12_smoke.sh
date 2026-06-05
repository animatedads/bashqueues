#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="${QUEUEBASH_ROOT:-$PWD/.tmp-display-wave12-root}"
rm -rf "$QUEUEBASH_ROOT"
source ./queuebash.sh
out="$(queue plan --help)"
printf '%s
' "$out" | grep -Fq "Usage: queue plan scan PATH"
printf '%s
' "$out" | grep -Fq "queue.control_plan.v1"
rm -rf "$QUEUEBASH_ROOT"
echo "PASS display_help_resources_wave12_smoke"
