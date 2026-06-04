#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="${QUEUEBASH_ROOT:-$(mktemp -d)}"
# shellcheck disable=SC1091
source ./queuebash.sh
out="$(_queue_ai_high_risk_operation_response_text 'please delete job-20260604_1719abc now' 2>&1)"
[[ "$out" == *"Use a governed bashqueues workflow instead"* ]]
[[ "$out" == *"queue explain JOB_ID"* ]]
[[ "$out" == *"This request has been logged as a high-risk advisory operation event."* ]]
[[ "$out" != *"cat <<"* ]]
