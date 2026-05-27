#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }
grep -q 'QUEUEBASH_VERSION="0.18.9"' queuebash.sh || fail 'version not bumped to 0.18.9'
grep -q 'queue dev functions \[--file FILE\]' queuebash.sh || fail 'queue dev functions --file usage missing'
grep -q 'queue dev extract FUNCTION \[--file FILE\]' queuebash.sh || fail 'queue dev extract --file usage missing'
for asset in secprofile netprofile fileprofile; do
  file="assets.d/${asset}.sh"
  grep -q 'QUEUEBASH_TRUST_PROVIDER' "$file" || fail "$asset missing trust provider environment hook"
  grep -q 'trust_provider=exec' "$file" || fail "$asset missing exec provider documentation/comment"
  grep -q '/etc/queuebash/policy/trust.conf' "$file" || fail "$asset missing canonical trust policy path"
  grep -q 'TRUST_ALLOWED_SIGNERS' "$file" || fail "$asset missing file-provider allowed signers"
  grep -q 'TRUST_DENY_SELF_SIGNED' "$file" || fail "$asset missing file-provider self-signed deny"
  grep -q 'public-key' "$file" || fail "$asset missing provider public-key lookup hook"
  grep -q 'signer-allowed' "$file" || fail "$asset missing provider signer authorization hook"
  grep -q '/etc/queuebash/interrogation/approved' "$file" || fail "$asset missing canonical /etc/queuebash profile path"
done
grep -q 'local key files as one implementation of trust' docs/TRUST_PROVIDERS.md || fail 'trust provider docs missing architecture statement'
grep -q '0.17.96 - trust provider interface' CHANGELOG.md || fail 'changelog entry missing'
echo '[PASS] trust provider interface static checks pass'
