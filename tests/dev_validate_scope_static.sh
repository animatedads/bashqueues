#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

grep -Eq 'queue dev validate .*\[--json\]' queuebash.sh
grep -Eq 'queue dev scope-check .*\[--json\]' queuebash.sh
grep -q '_queue_dev_validate_command' queuebash.sh
grep -q '_queue_dev_scope_check_command' queuebash.sh
grep -q 'queuebash.dev_validate_result.v1' queuebash.sh
grep -q 'queuebash.dev_scope_check_result.v1' queuebash.sh
grep -Eq 'dev validate|validate/scope-check' README.md
grep -q 'Queue Dev Validate and Scope Gates' docs/QUEUE_DEV_VALIDATE_SCOPE.md
