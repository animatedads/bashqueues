#!/usr/bin/env bash
set -euo pipefail
seconds="${1:-10}"
echo "SLEEPY: starting for ${seconds}s"
echo "SLEEPY: stderr start" >&2
sleep "$seconds"
echo "SLEEPY: finished"
exit 0
