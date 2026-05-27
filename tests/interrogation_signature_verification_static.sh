#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }
grep -q 'QUEUEBASH_VERSION="0.18.11"' queuebash.sh || fail 'version not bumped to 0.18.11'
grep -q 'queue profile interrogate verify NAME' queuebash.sh || fail 'verify usage missing'
grep -q 'def verify_cmd' bin/queue-interrogate-compile || fail 'verify command missing'
grep -q 'verify_profile_file' bin/queue-interrogate-compile || fail 'profile verify helper missing'
grep -q 'allow_self_signed' assets.d/secprofile.sh || fail 'secprofile trust parameter missing'
grep -q 'required_signer' assets.d/netprofile.sh || fail 'netprofile required signer parameter missing'
grep -q 'required_signer' assets.d/fileprofile.sh || fail 'fileprofile required signer parameter missing'
grep -q '0.17.93 - Ed25519 profile signing' CHANGELOG.md || fail 'changelog entry missing'
echo '[PASS] interrogation signature verification static checks pass'
