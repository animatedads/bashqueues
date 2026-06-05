#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "FAIL enterprise_profile_command_static: $*" >&2; exit 1; }
grep -q '_queue_enterprise_command()' queuebash.sh || fail 'missing queue enterprise command function'
grep -q 'enterprise_profile_verify.sh' queuebash.sh || fail 'queue enterprise command must call profile verifier helper'
grep -q 'maintenance_evidence_verify.sh' queuebash.sh || fail 'queue enterprise command must call maintenance evidence verifier helper'
grep -q 'queuebash.enterprise_profiles.v1' queuebash.sh || fail 'list-profiles --json schema missing'
grep -q 'queue enterprise list-profiles \[--json\]' queuebash.sh || fail 'enterprise help missing list-profiles usage'
grep -q 'queue enterprise validate-profile PROFILE \[--json\]' queuebash.sh || fail 'enterprise help missing validate-profile usage'
grep -q 'queue enterprise verify-maintenance --request FILE \[--json\]' queuebash.sh || fail 'enterprise help missing verify-maintenance usage'
grep -q 'activation_supported.*false' queuebash.sh || fail 'enterprise list-profiles must report activation unsupported'
grep -q 'system_modified.*false' queuebash.sh || fail 'enterprise list-profiles must report no system modification'
if grep -q 'enable-profile' queuebash.sh; then fail 'queue enterprise must not expose enable-profile'; fi
for profile in small-team-dev-default government-project-test-default hospital-live-readonly-default hospital-live-approved-maintenance-default; do
  grep -q "$profile" providers.d/enterprise/enterprise_profile_verify.sh || fail "verifier missing $profile support"
  grep -q "$profile" queuebash.sh || fail "queue enterprise list-profiles missing $profile"
done
echo 'PASS enterprise_profile_command_static'
