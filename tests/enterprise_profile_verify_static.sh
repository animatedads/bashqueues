#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
provider="providers.d/enterprise/enterprise_profile_verify.sh"
[[ -x "$provider" ]]
grep -q 'queuebash.enterprise_profile_verify.v1' "$provider"
grep -q 'fixture-only' "$provider"
grep -q 'live_clearance_granted' "$provider"
grep -q 'system_modified' "$provider"
grep -q 'QUEUEBASH_SECRET_ENV_ALLOWED' "$provider"
grep -q 'QUEUEBASH_AI_EXTERNAL_PROVIDER_ALLOWED' "$provider"
grep -q 'QUEUEBASH_POLICY_ROOT_MUST_BE_EXPLICIT' "$provider"
grep -q 'QUEUEBASH_POLICY_ROOT_COMPATIBILITY_REQUIRED' "$provider"
! grep -q 'source .*hospital-live' "$provider"
! grep -q '\. .*hospital-live' "$provider"
grep -q 'enterprise_profile_verify.sh --profile hospital-live-readonly-default --json' docs/HOSPITAL_LIVE_SAFE_MODE.md
grep -q 'queuebash.enterprise_profile_verify.v1' schemas/enterprise/profile_verify.example.json
printf 'PASS enterprise_profile_verify_static\n'
