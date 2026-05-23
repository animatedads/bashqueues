#!/usr/bin/env bash
set -euo pipefail
limit="${1:-10000}"
i=1
while [[ "$i" -le "$limit" ]]; do
    echo "LINE $i stdout"
    if (( i % 1000 == 0 )); then
        echo "LINE $i stderr checkpoint" >&2
    fi
    i=$((i + 1))
done
