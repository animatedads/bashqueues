#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

resources=(
  dev-qbtest-help.txt
  dev-qbtest-extract-help.txt
  dev-qbtest-add-help.txt
  dev-validate-help.txt
  dev-scope-check-help.txt
)
for name in "${resources[@]}"; do
  test -s "resources.d/display/lang_eng/$name"
  test -s "resources.d/display/fallback/$name"
  cmp -s "resources.d/display/lang_eng/$name" "resources.d/display/fallback/$name"
done

grep -Fq '_queue_resource_fetch_i18nl_command --name dev-qbtest-help.txt' queuebash.sh
grep -Fq '_queue_resource_fetch_i18nl_command --name dev-qbtest-extract-help.txt' queuebash.sh
grep -Fq '_queue_resource_fetch_i18nl_command --name dev-qbtest-add-help.txt' queuebash.sh
grep -Fq '_queue_resource_fetch_i18nl_command --name dev-validate-help.txt' queuebash.sh
grep -Fq '_queue_resource_fetch_i18nl_command --name dev-scope-check-help.txt' queuebash.sh

! grep -Fq 'Run embedded function tests stored as base64 comment blocks' queuebash.sh
! grep -Fq 'Extract the QBTEST block for the named function' queuebash.sh
! grep -Fq 'Insert a QBTEST block for the named function immediately after its closing brace' queuebash.sh
! grep -Fq 'Run a bounded development validation set. This is a reporting gate only' queuebash.sh
! grep -Fq 'Check a changed-file set against simple allow/deny globs' queuebash.sh
