#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -q 'QUEUEBASH_VERSION="0.18.6"' queuebash.sh || fail 'version not bumped to 0.18.6'
grep -q '0.17.98 - directory governance provider contracts' CHANGELOG.md || fail 'changelog entry missing'

for f in docs/DIRECTORY_GOVERNANCE_PROVIDERS.md docs/TRUST_PROVIDERS.md examples/providers/ldap.env.example examples/providers/pam.env.example; do
  [[ -f "$f" ]] || fail "missing $f"
done

grep -q 'queue-ldap-acl-check' docs/DIRECTORY_GOVERNANCE_PROVIDERS.md || fail 'LDAP ACL helper contract missing'
grep -q 'queue-ldap-policy-resolve' docs/DIRECTORY_GOVERNANCE_PROVIDERS.md || fail 'LDAP policy helper contract missing'
grep -q 'queue-ldap-key-resolve' docs/DIRECTORY_GOVERNANCE_PROVIDERS.md || fail 'LDAP key helper contract missing'
grep -q 'queue-pam-account-check' docs/DIRECTORY_GOVERNANCE_PROVIDERS.md || fail 'PAM account helper contract missing'
grep -q 'queue-pam-session-check' docs/DIRECTORY_GOVERNANCE_PROVIDERS.md || fail 'PAM session helper contract missing'
grep -q 'queue-nss-identity-resolve' docs/DIRECTORY_GOVERNANCE_PROVIDERS.md || fail 'NSS identity helper contract missing'
grep -q 'queue-pam-acl-check' docs/DIRECTORY_GOVERNANCE_PROVIDERS.md || fail 'PAM ACL helper contract missing'

grep -q '"schema": "queuebash.provider.v1"' docs/DIRECTORY_GOVERNANCE_PROVIDERS.md || fail 'provider schema missing'
grep -q '"provider": "ldap"' docs/DIRECTORY_GOVERNANCE_PROVIDERS.md || fail 'LDAP JSON example missing'
grep -q '"provider": "pam"' docs/DIRECTORY_GOVERNANCE_PROVIDERS.md || fail 'PAM JSON example missing'
grep -q '"required_assets"' docs/DIRECTORY_GOVERNANCE_PROVIDERS.md || fail 'required_assets JSON contract missing'
grep -q 'profile.approve' docs/DIRECTORY_GOVERNANCE_PROVIDERS.md || fail 'profile approval ACL example missing'
grep -q 'dev.patch' docs/DIRECTORY_GOVERNANCE_PROVIDERS.md || fail 'dev operation ACL example missing'
grep -q 'provider output is never evaluated as shell' docs/DIRECTORY_GOVERNANCE_PROVIDERS.md || fail 'no-shell-execution rule missing'
grep -q 'Single-user installations remain simple and file-backed' docs/DIRECTORY_GOVERNANCE_PROVIDERS.md || fail 'single-user simplicity rule missing'

grep -q '/etc/queuebash/policy/providers.d/ldap.env' docs/DIRECTORY_GOVERNANCE_PROVIDERS.md || fail 'LDAP canonical config path missing'
grep -q '/etc/queuebash/policy/providers.d/pam.env' docs/DIRECTORY_GOVERNANCE_PROVIDERS.md || fail 'PAM canonical config path missing'
grep -q '/var/cache/queuebash/ldap' docs/DIRECTORY_GOVERNANCE_PROVIDERS.md || fail 'LDAP canonical cache path missing'
grep -q '/var/cache/queuebash/pam' docs/DIRECTORY_GOVERNANCE_PROVIDERS.md || fail 'PAM canonical cache path missing'
grep -q '/usr/libexec/queuebash/providers/ldap' docs/DIRECTORY_GOVERNANCE_PROVIDERS.md || fail 'LDAP helper path missing'
grep -q '/usr/libexec/queuebash/providers/pam' docs/DIRECTORY_GOVERNANCE_PROVIDERS.md || fail 'PAM helper path missing'

if grep -R '/etc/bashqueues' docs/DIRECTORY_GOVERNANCE_PROVIDERS.md examples/providers/ldap.env.example examples/providers/pam.env.example >/dev/null; then
  fail 'new directory provider docs/examples must not introduce /etc/bashqueues namespace drift'
fi

grep -q 'Directory governance provider contracts' docs/TRUST_PROVIDERS.md || fail 'trust provider docs missing directory provider pointer'
grep -q 'queue-ldap-acl-check' docs/TRUST_PROVIDERS.md || fail 'trust provider docs missing LDAP helper pointer'
grep -q 'queue-pam-account-check' docs/TRUST_PROVIDERS.md || fail 'trust provider docs missing PAM helper pointer'
grep -q 'Directory governance provider contracts' README.md || fail 'README missing directory provider pointer'

echo '[PASS] Directory governance provider contract static checks pass'
