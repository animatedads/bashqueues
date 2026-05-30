#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -Eq 'QUEUEBASH_VERSION="0\.18\.(28|29|30|31|32|33|34|35|36|37|38|39|40|41|47|48|49|[5-9][0-9])"' queuebash.sh || fail 'version not bumped to 0.18.28 or newer'
grep -q '0.18.26 - Oracle Cloud Infrastructure governance provider contract' CHANGELOG.md || fail 'changelog entry missing'

for f in docs/OCI_GOVERNANCE_PROVIDER.md docs/TRUST_PROVIDERS.md examples/providers/oci.env.example; do
  [[ -f "$f" ]] || fail "missing $f"
done

grep -q 'queue-oci-auth-context' docs/OCI_GOVERNANCE_PROVIDER.md || fail 'auth context helper contract missing'
grep -q 'queue-oci-policy-resolve' docs/OCI_GOVERNANCE_PROVIDER.md || fail 'policy helper contract missing'
grep -q 'queue-oci-acl-check' docs/OCI_GOVERNANCE_PROVIDER.md || fail 'acl helper contract missing'
grep -q 'queue-oci-key-resolve' docs/OCI_GOVERNANCE_PROVIDER.md || fail 'key helper contract missing'
grep -q 'queue-oci-posture-check' docs/OCI_GOVERNANCE_PROVIDER.md || fail 'posture helper contract missing'
grep -q 'queue-oci-audit-evidence' docs/OCI_GOVERNANCE_PROVIDER.md || fail 'audit evidence helper contract missing'
grep -q '"schema": "queuebash.provider.v1"' docs/OCI_GOVERNANCE_PROVIDER.md || fail 'provider schema missing'
grep -q '"provider": "oci"' docs/OCI_GOVERNANCE_PROVIDER.md || fail 'provider oci JSON examples missing'
grep -q '"required_assets"' docs/OCI_GOVERNANCE_PROVIDER.md || fail 'required_assets JSON contract missing'
grep -q '"decision": "allow"' docs/OCI_GOVERNANCE_PROVIDER.md || fail 'allow decision contract missing'
grep -q '"decision": "deny"' docs/OCI_GOVERNANCE_PROVIDER.md || fail 'deny decision contract missing'
grep -q 'No returned value is evaluated as shell' docs/OCI_GOVERNANCE_PROVIDER.md || fail 'no-shell-execution rule missing'
grep -q 'provider output is never evaluated as shell' docs/OCI_GOVERNANCE_PROVIDER.md || fail 'provider parity no-shell rule missing'
grep -q 'job.submit' docs/OCI_GOVERNANCE_PROVIDER.md || fail 'job operation ACL examples missing'
grep -q 'profile.approve' docs/OCI_GOVERNANCE_PROVIDER.md || fail 'profile approval ACL example missing'
grep -q 'dev.patch' docs/OCI_GOVERNANCE_PROVIDER.md || fail 'dev operation ACL example missing'
grep -q 'Cloud Guard' docs/OCI_GOVERNANCE_PROVIDER.md || fail 'Cloud Guard posture evidence missing'
grep -q 'Work Requests' docs/OCI_GOVERNANCE_PROVIDER.md || fail 'work request evidence missing'
grep -q 'dynamic groups' docs/OCI_GOVERNANCE_PROVIDER.md || fail 'dynamic group model missing'
grep -q 'resource principals' docs/OCI_GOVERNANCE_PROVIDER.md || fail 'resource principal model missing'

grep -q '/etc/queuebash/policy/providers.d/oci.env' docs/OCI_GOVERNANCE_PROVIDER.md || fail 'canonical provider config path missing'
grep -q '/var/cache/queuebash/oci' docs/OCI_GOVERNANCE_PROVIDER.md || fail 'canonical provider cache path missing'
grep -q '/usr/libexec/queuebash/providers/oci' docs/OCI_GOVERNANCE_PROVIDER.md || fail 'canonical provider helper path missing'

if grep -R '/etc/bashqueues' docs/OCI_GOVERNANCE_PROVIDER.md examples/providers/oci.env.example >/dev/null; then
  fail 'new OCI provider docs/examples must not introduce /etc/bashqueues namespace drift'
fi

grep -q 'Oracle Cloud Infrastructure governance provider' docs/TRUST_PROVIDERS.md || fail 'trust provider docs missing OCI pointer'
grep -q 'queue-oci-policy-resolve' docs/TRUST_PROVIDERS.md || fail 'trust provider docs missing OCI policy helper pointer'
grep -q 'Oracle Cloud Infrastructure governance provider contract' README.md || fail 'README missing OCI provider pointer'

echo '[PASS] OCI governance provider contract static checks pass'
