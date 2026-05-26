#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
grep -q '_queue_code_sign_command' queuebash.sh
grep -q '_queue_code_verify_command' queuebash.sh
grep -q '_queue_code_signature_check_file_for_execution' queuebash.sh
grep -q 'code|codesign|code-signing' queuebash.sh
grep -q 'plugins)' queuebash.sh
test -f policies.d/code-signing/default.env
test -f docs/CODE_SIGNING.md
bash -n queuebash.sh
