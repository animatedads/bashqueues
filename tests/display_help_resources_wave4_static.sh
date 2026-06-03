#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

resources=(
  ask-help.txt
  dev-splice-help.txt
  dev-scratchpad-help.txt
  dev-test-help.txt
)
for name in "${resources[@]}"; do
  test -s "resources.d/display/lang_eng/$name"
  test -s "resources.d/display/fallback/$name"
  cmp -s "resources.d/display/lang_eng/$name" "resources.d/display/fallback/$name"
done

grep -Fq '_queue_resource_fetch_i18nl_command --name ask-help.txt' queuebash.sh
grep -Fq '_queue_resource_fetch_i18nl_command --name dev-splice-help.txt' queuebash.sh
grep -Fq '_queue_resource_fetch_i18nl_command --name dev-scratchpad-help.txt' queuebash.sh
grep -Fq '_queue_resource_fetch_i18nl_command --name dev-test-help.txt' queuebash.sh

# The large human help text should no longer be embedded in queuebash.sh.
! grep -Fq 'Local Ollama:' queuebash.sh
! grep -Fq 'queue dev splice --file FILE --after TEXT --insert TEXT' queuebash.sh
! grep -Fq 'File-backed authority-stamped development scratchpad ledger' queuebash.sh
! grep -Fq 'Submit and optionally run a real DEV_TEST_RUNNER job' queuebash.sh
