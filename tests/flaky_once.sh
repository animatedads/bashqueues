#!/usr/bin/env bash
set -euo pipefail
state_file="$1"
count="$(cat "$state_file" 2>/dev/null || echo 0)"
count=$((count + 1))
echo "$count" > "$state_file"
echo "FLAKY attempt $count"
if [[ "$count" -lt 2 ]]; then
    echo "FLAKY failing first attempt" >&2
    exit 42
fi
echo "FLAKY success"
exit 0
