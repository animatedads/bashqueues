#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
grep -q 'queue policy explain \[NAME\]' queuebash.sh
grep -q 'found_kind' queuebash.sh
grep -q 'kind="class-statement"' queuebash.sh
echo "[PASS] policy explain/show shorthand is wired"
