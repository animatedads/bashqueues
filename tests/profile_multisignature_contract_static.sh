#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "FAIL: $*" >&2; exit 1; }

[[ -f queuebash.sh ]] || fail "run from repository root"
grep -Eq 'QUEUEBASH_VERSION="0\.[0-9]+\.[0-9]+"' queuebash.sh || fail "queuebash version string missing/malformed"
grep -q 'queuebash.profile_signatures.v1' queuebash.sh docs/PROFILE_MULTISIGNATURE_CONTRACT.md examples/profiles/multisig/signatures.goodrexx.json.example || fail "profile signature schema missing"
grep -q 'queuebash.profile_signature_verification.v1' queuebash.sh docs/PROFILE_MULTISIGNATURE_CONTRACT.md || fail "verification schema missing"
grep -q 'self:NAME' docs/PROFILE_MULTISIGNATURE_CONTRACT.md || fail "self namespace missing"
grep -q 'team:NAME' docs/PROFILE_MULTISIGNATURE_CONTRACT.md || fail "team namespace missing"
grep -q 'org:NAME' docs/PROFILE_MULTISIGNATURE_CONTRACT.md || fail "org namespace missing"
grep -q 'external:NAME' docs/PROFILE_MULTISIGNATURE_CONTRACT.md || fail "external namespace missing"
grep -q 'trusted-ca:NAME' docs/PROFILE_MULTISIGNATURE_CONTRACT.md || fail "trusted-ca namespace missing"
grep -q 'queue profile-signature verify' docs/PROFILE_MULTISIGNATURE_CONTRACT.md queuebash.sh || fail "command surface missing"
grep -q 'cryptographic_verification_performed' queuebash.sh docs/PROFILE_MULTISIGNATURE_CONTRACT.md || fail "contract-only crypto marker missing"
! grep -R '/etc/bashqueues' docs/PROFILE_MULTISIGNATURE_CONTRACT.md policies.d/profile-signatures examples/profiles/multisig >/dev/null || fail "stale /etc/bashqueues path in profile multisig files"

echo "PASS profile multi-signature contract static"
