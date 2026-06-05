#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

for name in acl-provider-mutable-handoff.txt module-acl-provider-handoff.txt; do
  test -s "resources.d/display/lang_eng/$name"
  test -s "resources.d/display/fallback/$name"
  cmp -s "resources.d/display/lang_eng/$name" "resources.d/display/fallback/$name"
done

grep -Fq '_queue_resource_fetch_i18nl_command --name acl-provider-mutable-handoff.txt' queuebash.sh
grep -Fq '_queue_resource_fetch_i18nl_command --name module-acl-provider-handoff.txt' queuebash.sh

! grep -Fq 'Only the local file provider is mutable in 0.18.15.' queuebash.sh
! grep -Fq 'This command surface is reserved for the ACL subsystem. It is equivalent to:' queuebash.sh

bash -n queuebash.sh
