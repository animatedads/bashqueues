#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export QUEUEBASH_CLOUD_INFRA_REGISTRY="$ROOT/tests/fixtures/cloud_infra/registry.json"
export QUEUEBASH_CLOUD_INFRA_LIVE=0

check_plan(){
  local service="$1" provider="$2" family="$3"
  local out
  out="$(providers.d/cloud_infra/cloud_infra.sh plan "$service" start)"
  echo "$out" | /usr/bin/python3 -c 'import json,sys; expected_provider, expected_family=sys.argv[1:3]; d=json.load(sys.stdin); assert d["schema"]=="queuebash.cloud_infra.action.v1", d; assert d["decision"]=="dry_run", d; assert d["provider"]==expected_provider, d; assert d["provider_family"]==expected_family, d; assert d["action"]=="plan-start", d; assert d["live"] is False and d["mutated"] is False, d; assert d["registry_checked"] is True, d' "$provider" "$family"
}

check_plan ovh-gdpr-vm ovhcloud eu_sovereign
check_plan scaleway-gdpr-instance scaleway eu_sovereign
check_plan hetzner-gdpr-cloud hetzner eu_sovereign
check_plan otc-gdpr-ecs otc eu_sovereign
check_plan alibaba-export-review-ecs alibaba apac_china
check_plan tencent-export-review-cvm tencent apac_china
check_plan huawei-export-review-ecs huawei apac_china

if providers.d/cloud_infra/cloud_infra.sh start alibaba-export-review-ecs >/tmp/apac_start.json 2>/dev/null; then
  echo 'start unexpectedly allowed for apac helper' >&2
  exit 1
fi
/usr/bin/python3 -c 'import json; d=json.load(open("/tmp/apac_start.json")); assert d["decision"]=="deny", d; assert d.get("fail_closed") is True, d'

echo 'cloud_infra_eu_apac_helper_parity_smoke: PASS'
