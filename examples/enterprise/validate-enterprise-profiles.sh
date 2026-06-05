#!/usr/bin/env bash
set -euo pipefail

# Safe validation wrapper. It validates inert enterprise examples only; it does
# not activate policy, install files, grant live clearance, or deliver secrets.

if ! command -v queue >/dev/null 2>&1; then
  if [[ -f ./queuebash.sh ]]; then
    # shellcheck disable=SC1091
    source ./queuebash.sh
  else
    echo "queue command not found; source queuebash.sh or install the wrapper first" >&2
    exit 2
  fi
fi

queue policy paths --json
queue policy status --json
queue enterprise list-profiles --json

for profile in \
  small-team-dev-default \
  government-project-test-default \
  hospital-live-readonly-default \
  hospital-live-approved-maintenance-default
 do
  queue enterprise validate-profile "$profile" --json
 done
