#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for f in \
  docs/APAC_CHINA_PROVIDER_CONTRACTS.md \
  docs/APAC_CHINA_CLASS_CRITERIA.md \
  docs/APAC_CHINA_EXPLAINABILITY.md \
  docs/APAC_CHINA_LEGAL_COMPLIANCE.md \
  providers.d/apac_china/apac_china_provider.sh \
  policies.d/apac-china/default.env.example \
  policies.d/apac-china/regions.tsv \
  classes/CLOUD_APAC_CHINA_DEFAULT.env \
  classes/CLOUD_APAC_CHINA_GDPR.env \
  classes/CLOUD_APAC_CHINA_HIGH_ASSURANCE.env \
  tests/fixtures/apac_china/alibaba/detect.json; do
  [[ -f "$f" ]] || { echo "missing $f" >&2; exit 1; }
done

grep -Eq 'QUEUEBASH_VERSION="0\.18\.(35|36|37|38|39|4[0-9]|([5-9][0-9]|[1-9][0-9][0-9]))"' queuebash.sh
grep -q '0.18.46 BOB2 primary-source validation + BOB12 patchset registry merged' CHANGELOG.md || grep -q '0.18.46 - BOB2 primary-source validation + BOB12 patchset registry merged' CHANGELOG.md || grep -q '0.18.35 - APAC/China cloud provider contracts' CHANGELOG.md
grep -q '0.18.46 BOB2 primary-source validation + BOB12 patchset registry merged' README.md || grep -q '0.18.46 - BOB2 primary-source validation + BOB12 patchset registry merged' README.md || grep -q '0.18.35 APAC/China cloud provider contracts' README.md
grep -q 'queuebash.apac_china.alibaba.detect.v1' docs/APAC_CHINA_PROVIDER_CONTRACTS.md
grep -q 'mapped pending validation' docs/APAC_CHINA_LEGAL_COMPLIANCE.md
grep -q 'signed_url_redaction' classes/CLOUD_APAC_CHINA_GDPR.env
grep -q 'QUEUEBASH_APAC_CHINA_LIVE_CHECKS=0' policies.d/apac-china/default.env.example
grep -q 'Live provider checks are intentionally not implemented' providers.d/apac_china/apac_china_provider.sh
for p in alibaba tencent huawei; do
  [[ -d "tests/fixtures/apac_china/$p" ]] || exit 1
  grep -q "queuebash.apac_china.$p.detect.v1" "tests/fixtures/apac_china/$p/detect.json"
done
if grep -q '_queue_apac_china\|queue apac-china\|queue apac_china\|aliyun ecs CreateInstance\|tccli cvm RunInstances\|huaweicloud.*create\|hcloud server create' queuebash.sh providers.d/apac_china/apac_china_provider.sh docs/APAC_CHINA_PROVIDER_CONTRACTS.md; then
  echo 'unexpected APAC/China dispatcher/live provisioning hook found' >&2
  exit 1
fi
[[ ! -e assets.d/net_usage.sh ]]
[[ -e caps.d/net_usage.sh ]]
echo 'PASS apac_china_provider_contracts_static'
