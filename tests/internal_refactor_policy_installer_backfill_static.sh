#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "FAIL: $*" >&2; exit 1; }

grep -q 'QUEUEBASH_VERSION="0.18.22"' queuebash.sh || fail 'version not bumped to 0.18.22'
grep -q '_queue_install_bundled_tree_files()' queuebash.sh || fail 'missing bundled tree install helper'
grep -q '_queue_install_bundled_policy_family()' queuebash.sh || fail 'missing policy family installer helper'
grep -q '_queue_install_bundled_policy_top_level()' queuebash.sh || fail 'missing top-level compatibility policy installer'
grep -q '_queue_install_bundled_policies()' queuebash.sh || fail 'missing policy installer wrapper'

# Legacy families must remain explicit.
grep -q 'sandbox "\*\.env"' queuebash.sh || fail 'sandbox policy family lost'
grep -q 'seccomp "\*\.env"' queuebash.sh || fail 'seccomp policy family lost'
grep -q 'class-statement "\*\.env"' queuebash.sh || fail 'class-statement policy family lost'

# Newer provider/governance families must be covered deliberately.
for family in acl key profile-signatures finops legal-registry sovereign reporting security snmp-map; do
    grep -q "$family" queuebash.sh || fail "missing bundled policy family: $family"
done

grep -q 'endpoint_jurisdiction.env legal_framework.env legal_registry.env' queuebash.sh || fail 'top-level compatibility policy files not handled deliberately'
grep -q '\.disabled/\$base' queuebash.sh || fail 'disabled marker protection missing'
grep -q '! -e "\$dst"' queuebash.sh || fail 'no-overwrite guard missing'
if grep -n '_queue_install_bundled_policies' -A80 queuebash.sh | grep -q 'cp -f'; then
    fail 'destructive overwrite cp -f found in policy installer'
fi

echo 'PASS internal refactor policy installer backfill static'
