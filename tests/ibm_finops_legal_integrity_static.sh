#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail(){ echo "FAIL $*" >&2; exit 1; }

grep -Eq 'QUEUEBASH_VERSION="0\.[0-9]+\.[0-9]+"' queuebash.sh || fail "queuebash version string missing/malformed"
[[ -f policies.d/finops/ibm.env.example ]] || fail 'missing IBM FinOps policy example'
[[ -f policies.d/legal-registry/ibm.example.tsv ]] || fail 'missing IBM legal registry example'
[[ -f examples/manifests/ibm_finreg.manifest.example ]] || fail 'missing IBM integrity manifest example'
[[ -f examples/ibm/ibm_cost_cache.json.example ]] || fail 'missing IBM cost cache example'
[[ -f examples/ibm/ibm_finops.health.example ]] || fail 'missing IBM health example'

grep -q 'queuebash.ibm_finops_cache.v1' policies.d/finops/ibm.env.example || fail 'missing IBM FinOps cache schema in policy example'
grep -q '/etc/queuebash/finops/ibm_cost_cache.json' policies.d/finops/ibm.env.example || fail 'IBM FinOps example must use /etc/queuebash'
grep -q '/etc/queuebash/legal_registry.tsv' docs/IBM_CLOUD_GOVERNANCE.md || fail 'IBM docs must use canonical legal registry path'
grep -q '/etc/queuebash/manifests/ibm_finreg.manifest' docs/IBM_CLOUD_GOVERNANCE.md || fail 'IBM docs must use canonical manifest path'

grep -q 'queue_class_shared_asset ibm_finops cost_cache_fresh' classes/CLOUD_IBM_FINREG.env || fail 'FINREG missing IBM FinOps freshness gate'
grep -q 'queue_class_shared_asset ibm_finops budget_remaining' classes/CLOUD_IBM_FINREG.env || fail 'FINREG missing IBM budget gate'
grep -q 'queue_class_shared_asset ibm_finops anomaly_free' classes/CLOUD_IBM_FINREG.env || fail 'FINREG missing IBM anomaly gate'
grep -q 'queue_class_shared_asset ibm_finops cost_cache_fresh' classes/CLOUD_IBM_LEGAL_COMPLIANCE.env || fail 'LEGAL_COMPLIANCE missing IBM FinOps freshness gate'

grep -q '/etc/queuebash/legal_registry.tsv' assets.d/legal.sh || fail 'legal asset default must use /etc/queuebash'
! grep -q '/etc/bashqueues/legal_registry.tsv' assets.d/legal.sh || fail 'legal asset retained stale /etc/bashqueues legal registry path'
! grep -q '/etc/bashqueues/manifests/' assets.d/integrity.sh || fail 'integrity hints retained stale /etc/bashqueues manifest path'
[[ ! -e assets.d/net_usage.sh ]] || fail 'assets.d/net_usage.sh must remain absent'

echo "PASS tests/ibm_finops_legal_integrity_static.sh"
