#!/usr/bin/env bash
set -euo pipefail

# Safe maintenance evidence wrapper. It checks the request JSON only; it does
# not approve live work, install policy, or mutate the system.

request="${1:-examples/enterprise/maintenance-request.example.json}"

if ! command -v queue >/dev/null 2>&1; then
  if [[ -f ./queuebash.sh ]]; then
    # shellcheck disable=SC1091
    source ./queuebash.sh
  else
    echo "queue command not found; source queuebash.sh or install the wrapper first" >&2
    exit 2
  fi
fi

queue enterprise verify-maintenance --request "$request" --json
