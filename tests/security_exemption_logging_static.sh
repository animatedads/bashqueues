#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
grep -q 'SECURITY_EXEMPTION_TYPE' queuebash.sh
grep -q 'policy-approved' queuebash.sh
grep -q 'description-approved' queuebash.sh
grep -q 'code-approved' queuebash.sh
grep -q '_queue_authorisation_find_valid_for_command' queuebash.sh
grep -q 'pol_block' queuebash.sh
echo '[PASS] security exemption logging and pol_block hooks are present'
