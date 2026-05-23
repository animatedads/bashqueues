#!/usr/bin/env bash
set -euo pipefail
echo "PARENT $$ starting child"
sleep "${1:-20}" &
child="$!"
echo "CHILD $child started"
wait "$child"
