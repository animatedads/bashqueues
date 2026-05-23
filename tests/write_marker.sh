#!/usr/bin/env bash
set -euo pipefail
marker="$1"
text="${2:-marker}"
echo "$text" > "$marker"
