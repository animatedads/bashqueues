#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -q 'QUEUEBASH_VERSION="0.18.9"' queuebash.sh || fail 'version not bumped to 0.18.9'
grep -q '0.17.97 - Microsoft governance provider contract' CHANGELOG.md || fail 'changelog entry missing'

for f in docs/MS_GOVERNANCE_PROVIDER.md docs/TRUST_PROVIDERS.md examples/providers/microsoft.env.example; do
  [[ -f "$f" ]] || fail "missing $f"
done

grep -q 'queue-ms-token' docs/MS_GOVERNANCE_PROVIDER.md || fail 'token helper contract missing'
grep -q 'queue-ms-policy-resolve' docs/MS_GOVERNANCE_PROVIDER.md || fail 'policy helper contract missing'
grep -q 'queue-ms-acl-check' docs/MS_GOVERNANCE_PROVIDER.md || fail 'acl helper contract missing'
grep -q 'queue-ms-key-resolve' docs/MS_GOVERNANCE_PROVIDER.md || fail 'key helper contract missing'
grep -q '"schema": "queuebash.provider.v1"' docs/MS_GOVERNANCE_PROVIDER.md || fail 'provider schema missing'
grep -q '"required_assets"' docs/MS_GOVERNANCE_PROVIDER.md || fail 'required_assets JSON contract missing'
grep -q '"decision": "allow"' docs/MS_GOVERNANCE_PROVIDER.md || fail 'decision contract missing'
grep -q 'No returned value is evaluated as shell' docs/MS_GOVERNANCE_PROVIDER.md || fail 'no-shell-execution rule missing'
grep -q 'job.submit' docs/MS_GOVERNANCE_PROVIDER.md || fail 'command operation ACL examples missing'
grep -q 'profile.approve' docs/MS_GOVERNANCE_PROVIDER.md || fail 'profile approval ACL example missing'
grep -q 'dev.patch' docs/MS_GOVERNANCE_PROVIDER.md || fail 'dev operation ACL example missing'
grep -q 'LDAP and PAM.d' docs/MS_GOVERNANCE_PROVIDER.md || fail 'LDAP/PAM provider parity note missing'

grep -q '/etc/queuebash/policy/providers.d/microsoft.env' docs/MS_GOVERNANCE_PROVIDER.md || fail 'canonical provider config path missing'
grep -q '/var/cache/queuebash/ms' docs/MS_GOVERNANCE_PROVIDER.md || fail 'canonical provider cache path missing'
grep -q '/usr/libexec/queuebash/providers/microsoft' docs/MS_GOVERNANCE_PROVIDER.md || fail 'canonical provider helper path missing'

if grep -R '/etc/bashqueues' docs/MS_GOVERNANCE_PROVIDER.md examples/providers/microsoft.env.example >/dev/null; then
  fail 'new Microsoft provider docs/examples must not introduce /etc/bashqueues namespace drift'
fi

grep -q 'Microsoft governance provider' docs/TRUST_PROVIDERS.md || fail 'trust provider docs missing Microsoft pointer'
grep -q 'Microsoft systems provide authoritative policy' docs/TRUST_PROVIDERS.md || fail 'trust provider docs missing provider principle'

echo '[PASS] Microsoft governance provider contract static checks pass'
