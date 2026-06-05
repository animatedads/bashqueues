#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
out="$(QUEUEBASH_ALLOW_NONINTERACTIVE=1 bash -lc 'source ./queuebash.sh; queue platform --help')"
printf '%s\n' "$out" | grep -Fq 'Usage: queue platform [--json]'
printf '%s\n' "$out" | grep -Fq 'WSL2-first'
