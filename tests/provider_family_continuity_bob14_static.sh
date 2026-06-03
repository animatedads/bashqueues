#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

for f in \
  docs/PROVIDER_FAMILY_CONTINUITY_REVIEW_0.18.88.md \
  docs/PROVIDER_SERVICE_COVERAGE_ROADMAP.md \
  docs/PROVIDER_FAMILY_CONSISTENCY.md \
  docs/PLATFORM_PARITY_STATUS.md \
  policies.d/cloud-resource/provider-family-consistency.json \
  tests/provider_family_consistency_json_contract_static.py; do
  [[ -f "$f" ]] || fail "missing $f"
done

grep -q 'Bob14 inherits Bob2' docs/PROVIDER_FAMILY_CONTINUITY_REVIEW_0.18.88.md || fail 'Bob14 handover missing'
grep -q 'provider-family metadata' docs/PROVIDER_FAMILY_CONTINUITY_REVIEW_0.18.88.md || fail 'metadata defect evidence missing'
grep -q 'keeping IBM as `high_standard_reference`' docs/PROVIDER_FAMILY_CONTINUITY_REVIEW_0.18.88.md || fail 'IBM non-promotion note missing'
grep -q 'Provider-family continuity quick links' README.md || fail 'README provider-family quick links missing'
grep -q '0.18.88 BOB14 provider-family continuity review' CHANGELOG.md || fail 'CHANGELOG 0.18.88 Bob14 entry missing'
grep -qi 'model registry' docs/PROVIDER_SERVICE_COVERAGE_ROADMAP.md || fail 'model registry roadmap missing'
grep -qi 'container registry' docs/PROVIDER_SERVICE_COVERAGE_ROADMAP.md || fail 'container registry roadmap missing'

python3 - <<'PY'
import json
from pathlib import Path
root = Path.cwd()
policy = json.loads((root / 'policies.d/cloud-resource/provider-family-consistency.json').read_text())
ibm = policy['families']['ibm']
assert ibm['status'] == 'high_standard_reference'
assert ibm['provider_dir'] == 'ibm'
assert ibm['policy_dir'] == 'ibm'
assert ibm['fixture_dir'] == 'ibm'
assert ibm['doc_prefix'] == 'IBM'
for path in [
    'providers.d/ibm/ibm_provider.sh',
    'policies.d/ibm/finops.env',
    'tests/fixtures/ibm/detect.json',
    'docs/IBM_PROVIDER_CONTRACTS.md',
    'docs/IBM_CLASS_CRITERIA.md',
    'docs/IBM_EXPLAINABILITY.md',
    'docs/IBM_LEGAL_COMPLIANCE.md',
    'tests/ibm_provider_contracts_static.sh',
    'tests/ibm_provider_fixture_smoke.sh',
    'tests/ibm_provider_json_contract_static.py',
    'tests/ibm_explain_static.sh',
]:
    assert (root / path).exists(), path
PY

if grep -R -nE 'aws ec2 run-instances|az vm create|gcloud compute instances create|oci compute instance launch|openstack server create|kubectl apply|cf deploy|fly deploy|fastly compute publish' \
  docs/PROVIDER_FAMILY_CONTINUITY_REVIEW_0.18.88.md docs/PROVIDER_SERVICE_COVERAGE_ROADMAP.md docs/PROVIDER_FAMILY_CONSISTENCY.md docs/PLATFORM_PARITY_STATUS.md policies.d/cloud-resource/provider-family-consistency.json >/tmp/bob14_provider_forbidden.$$ 2>/dev/null; then
  cat /tmp/bob14_provider_forbidden.$$ >&2
  rm -f /tmp/bob14_provider_forbidden.$$
  fail 'live/provisioning command leaked into Bob14 provider-family continuity patch'
fi
rm -f /tmp/bob14_provider_forbidden.$$

[[ ! -e assets.d/net_usage.sh ]] || fail 'assets.d/net_usage.sh must remain absent'
[[ -e caps.d/net_usage.sh ]] || fail 'caps.d/net_usage.sh must remain present'

echo 'PASS provider_family_continuity_bob14_static'
