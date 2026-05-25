#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUEUE="$ROOT/queuebash.sh"

grep -q 'status="invalid-source"' "$QUEUE"
grep -q 'integrity=%-24s' "$QUEUE"
if grep -q 'line=.*\$'"'"'\\t'"'"'' "$QUEUE"; then
    echo "FAIL: authorisation list still builds invalid-source rows using literal shell-escaped tab fragments" >&2
    exit 1
fi

echo "[PASS] authorisation list invalid-source rows are rendered cleanly"
