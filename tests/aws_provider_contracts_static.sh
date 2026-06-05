#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
fail(){ echo "[FAIL] $*" >&2; exit 1; }
grep -Eq 'QUEUEBASH_VERSION="0\.18\.(33|34|35|36|37|38|39|40|41|46|47|48|49|([5-9][0-9]|[1-9][0-9][0-9]))"' queuebash.sh || fail 'version not bumped to 0.18.31 or newer'
grep -q '0.18.46 BOB2 primary-source validation + BOB12 patchset registry merged' CHANGELOG.md || grep -q '0.18.46 - BOB2 primary-source validation + BOB12 patchset registry merged' CHANGELOG.md || grep -q '0.18.35 - APAC/China cloud provider contracts' CHANGELOG.md || fail 'changelog entry missing'
grep -q '0.18.46 BOB2 primary-source validation + BOB12 patchset registry merged' README.md || grep -q '0.18.46 - BOB2 primary-source validation + BOB12 patchset registry merged' README.md || grep -q '0.18.35 APAC/China cloud provider contracts' README.md || fail 'README entry missing'
for f in docs/AWS_PROVIDER_CONTRACTS.md docs/AWS_LEGAL_COMPLIANCE.md providers.d/aws/aws_provider.sh assets.d/aws.sh policies.d/aws/default.env.example policies.d/aws/regions.tsv policies.d/aws/legal-frameworks.example.tsv policies.d/aws/cost-policy.example.json examples/cloud-resource/aws-vm-gdpr.example.json classes/CLOUD_AWS_GDPR.env classes/CLOUD_AWS_DATA_PROTECTION.env classes/CLOUD_AWS_ITAR.env classes/CLOUD_AWS_FINOPS.env classes/CLOUD_AWS_HIGH_ASSURANCE.env; do [[ -f "$f" ]] || fail "missing $f"; done
bash -n providers.d/aws/aws_provider.sh || fail 'aws provider bash -n failed'
bash -n assets.d/aws.sh || fail 'aws asset bash -n failed'
for f in classes/CLOUD_AWS_*.env; do bash -n "$f" || fail "class bash -n failed: $f"; done
grep -q 'queuebash.aws.identity.v1' docs/AWS_PROVIDER_CONTRACTS.md || fail 'AWS identity schema missing'
grep -q 'queuebash.aws.data_protection.v1' docs/AWS_PROVIDER_CONTRACTS.md || fail 'AWS data protection schema missing'
grep -q 'queuebash.aws.itar.v1' docs/AWS_PROVIDER_CONTRACTS.md || fail 'AWS ITAR schema missing'
grep -q 'queuebash.aws.finops.v1' docs/AWS_PROVIDER_CONTRACTS.md || fail 'AWS FinOps schema missing'
grep -q 'aws:auth_active' assets.d/aws.sh || fail 'AWS auth asset missing'
grep -q 'aws:region_allowed' assets.d/aws.sh || fail 'AWS region asset missing'
grep -q 'aws:finops_budget_ok' assets.d/aws.sh || fail 'AWS FinOps asset missing'
grep -q 'CLOUD_AWS_ITAR' classes/CLOUD_AWS_ITAR.env || fail 'AWS ITAR class missing marker'
grep -q 'AWS_ITAR' policies.d/aws/legal-frameworks.example.tsv || fail 'AWS ITAR legal framework missing'
grep -q 'AWS_GDPR' policies.d/aws/legal-frameworks.example.tsv || fail 'AWS GDPR legal framework missing'
if grep -R 'run-instances\|terminate-instances\|create-user\|put-user-policy\|create-policy\|delete-bucket\|create-bucket' providers.d/aws assets.d/aws.sh docs/AWS_PROVIDER_CONTRACTS.md >/dev/null 2>&1; then fail 'AWS first-tier package must not contain live provisioning/IAM/storage mutation commands'; fi
[[ ! -e assets.d/net_usage.sh ]] || fail 'assets.d/net_usage.sh must remain absent'
[[ -f caps.d/net_usage.sh ]] || fail 'caps.d/net_usage.sh expected present'
echo '[PASS] aws provider contracts static checks pass'
