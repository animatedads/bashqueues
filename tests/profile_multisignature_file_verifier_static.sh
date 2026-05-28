#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

grep -q 'QUEUEBASH_VERSION="0.18.22"' queuebash.sh
grep -q 'file_verifier' queuebash.sh
grep -q 'key_provider_consulted' queuebash.sh
grep -q 'profile.sign' queuebash.sh
grep -q 'cryptographic_verification_performed' queuebash.sh
grep -q 'not_performed' queuebash.sh
grep -q 'queuebash.profile_signature_verification.v1' docs/PROFILE_MULTISIGNATURE_CONTRACT.md
grep -q 'key-provider registry contract' docs/PROFILE_MULTISIGNATURE_CONTRACT.md
! grep -R '/etc/bashqueues' docs/PROFILE_MULTISIGNATURE_CONTRACT.md examples/profiles policies.d/profile-signatures tests/profile_multisignature_file_verifier_static.sh >/dev/null 2>&1

echo 'PASS profile multisignature file verifier static'
