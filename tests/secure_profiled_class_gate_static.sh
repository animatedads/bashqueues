#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }
grep -q 'QUEUEBASH_VERSION="0.18.6"' queuebash.sh || fail 'version not bumped to 0.18.6'
grep -q '_queue_profile_class_template' queuebash.sh || fail 'class template helper missing'
grep -q 'queue profile interrogate class-template CLASS --profile NAME' queuebash.sh || fail 'class-template usage missing'
grep -q 'queue_class_shared_asset secprofile profile_verified "$PROFILE_NAME"' classes/SECURE_PROFILED.env || fail 'SECURE_PROFILED missing secprofile gate'
grep -q 'queue_class_shared_asset netprofile profile_verified "$PROFILE_NAME"' classes/SECURE_PROFILED.env || fail 'SECURE_PROFILED missing netprofile gate'
grep -q 'queue_class_shared_asset fileprofile profile_verified "$PROFILE_NAME"' classes/SECURE_PROFILED.env || fail 'SECURE_PROFILED missing fileprofile gate'
grep -q 'PROFILE_ALLOW_SELF_SIGNED="${PROFILE_ALLOW_SELF_SIGNED:-0}"' classes/SECURE_PROFILED.env || fail 'SECURE_PROFILED does not default self-signed profiles off'
grep -q '0.17.94 - secure profiled class gate' CHANGELOG.md || fail 'changelog entry missing'
echo '[PASS] secure profiled class gate static checks pass'
