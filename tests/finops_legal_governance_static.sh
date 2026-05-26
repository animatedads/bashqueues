#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -q 'QUEUEBASH_VERSION="0.17.78"' queuebash.sh || fail "version not bumped"
grep -q 'finops:anomaly_free' assets.d/finops.sh || fail "finops anomaly facility missing"
grep -q 'queue_asset_check_finops_anomaly_free' assets.d/finops.sh || fail "finops anomaly checker missing"
grep -q 'legal:retention_respected' assets.d/legal.sh || fail "legal retention facility missing"
grep -q 'queue_asset_check_legal_retention_respected' assets.d/legal.sh || fail "legal retention checker missing"
grep -q 'registry_under_queue_root_requires_allow_user_registry' assets.d/legal.sh || fail "legal registry safety check missing"
[[ -x bin/queue-finops-analyze ]] || fail "queue-finops-analyze not executable"
[[ -f classes/CLOUD_MULTI_FINOPS_SENSITIVE.env ]] || fail "FinOps class missing"
[[ -f classes/LEGAL_READONLY.env ]] || fail "legal readonly class missing"
[[ -f classes/LEGAL_COMPLIANCE.env ]] || fail "legal compliance class missing"
[[ ! -e assets.d/net_usage.sh ]] || fail "assets.d/net_usage.sh must remain absent"

echo '[PASS] FinOps/legal governance static checks pass'
