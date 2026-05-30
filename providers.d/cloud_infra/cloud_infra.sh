#!/usr/bin/env bash
set -euo pipefail

_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_registry="${QUEUEBASH_CLOUD_INFRA_REGISTRY:-}"
if [[ -z "$_registry" ]]; then
  _repo_root="$(cd "$_self_dir/../.." && pwd)"
  _registry="$_repo_root/policies.d/cloud-infra/registry.json"
  [[ -f "$_registry" ]] || _registry="$_repo_root/policies.d/cloud-infra/registry.example.json"
fi
_python="${QUEUEBASH_PYTHON:-/usr/bin/python3}"

_json_error() {
  local reason="$1" rc="${2:-2}"
  "$_python" - "$reason" <<'PY'
import json, sys
print(json.dumps({
  "schema":"queuebash.cloud_infra.error.v1",
  "decision":"deny",
  "reason":sys.argv[1],
  "registry_checked":False,
  "fail_closed":True
}, sort_keys=True))
PY
  exit "$rc"
}

_read_service() {
  local service_id="$1" action="${2:-explain}"
  "$_python" - "$_registry" "$service_id" "$action" <<'PY'
import json, sys
path, sid, action = sys.argv[1:4]
try:
    with open(path, encoding="utf-8") as f:
        reg=json.load(f)
except Exception as e:
    print(json.dumps({"schema":"queuebash.cloud_infra.lookup.v1","decision":"deny","reason":"registry_unreadable","error":str(e),"registry_checked":False,"fail_closed":True}, sort_keys=True))
    sys.exit(3)
services=reg.get("services", [])
for svc in services:
    if svc.get("id") == sid:
        allowed_actions = set(svc.get("allowed_actions", []))
        allowed = action in allowed_actions or action == "explain" or (action.startswith("plan-") and "plan" in allowed_actions)
        enabled = bool(svc.get("enabled", False))
        out={"schema":"queuebash.cloud_infra.lookup.v1","decision":"allow" if (enabled and allowed) else "deny","reason":"service_allowed" if (enabled and allowed) else ("service_disabled" if not enabled else "action_not_allowed"),"registry_checked":True,"registry_path":path,"service":svc,"fail_closed": not (enabled and allowed)}
        print(json.dumps(out, sort_keys=True))
        sys.exit(0 if (enabled and allowed) else 4)
print(json.dumps({"schema":"queuebash.cloud_infra.lookup.v1","decision":"deny","reason":"service_not_found","registry_checked":True,"registry_path":path,"service_id":sid,"fail_closed":True}, sort_keys=True))
sys.exit(4)
PY
}

_list_services() {
  "$_python" - "$_registry" <<'PY'
import json, sys
path=sys.argv[1]
with open(path, encoding="utf-8") as f:
    reg=json.load(f)
items=[]
for svc in reg.get("services", []):
    items.append({k:svc.get(k) for k in ("id","provider","helper","enabled","allowed_actions","region")})
print(json.dumps({"schema":"queuebash.cloud_infra.list.v1","registry_checked":True,"registry_path":path,"services":items}, sort_keys=True))
PY
}

_dispatch_helper() {
  local service_id="$1" action="$2"
  local lookup helper provider
  lookup="$(_read_service "$service_id" "$action")" || { printf '%s\n' "$lookup"; return 4; }
  helper="$(printf '%s\n' "$lookup" | "$_python" -c 'import json,sys; print(json.load(sys.stdin)["service"].get("helper",""))')"
  provider="$(printf '%s\n' "$lookup" | "$_python" -c 'import json,sys; print(json.load(sys.stdin)["service"].get("provider",""))')"
  case "$helper" in
    oci_free) exec "$_self_dir/oci_free_stack.sh" "$action" "$service_id" "$lookup" ;;
    ibm_vpc) exec "$_self_dir/ibm_vpc_stack.sh" "$action" "$service_id" "$lookup" ;;
    aws_ec2) exec "$_self_dir/aws_ec2_stack.sh" "$action" "$service_id" "$lookup" ;;
    azure_vm) exec "$_self_dir/azure_vm_stack.sh" "$action" "$service_id" "$lookup" ;;
    gcp_compute) exec "$_self_dir/gcp_compute_stack.sh" "$action" "$service_id" "$lookup" ;;
    ovh_vm) exec "$_self_dir/ovh_vm_stack.sh" "$action" "$service_id" "$lookup" ;;
    scaleway_instance) exec "$_self_dir/scaleway_instance_stack.sh" "$action" "$service_id" "$lookup" ;;
    hetzner_cloud) exec "$_self_dir/hetzner_cloud_stack.sh" "$action" "$service_id" "$lookup" ;;
    otc_ecs) exec "$_self_dir/otc_ecs_stack.sh" "$action" "$service_id" "$lookup" ;;
    alibaba_ecs) exec "$_self_dir/alibaba_ecs_stack.sh" "$action" "$service_id" "$lookup" ;;
    tencent_cvm) exec "$_self_dir/tencent_cvm_stack.sh" "$action" "$service_id" "$lookup" ;;
    huawei_ecs) exec "$_self_dir/huawei_ecs_stack.sh" "$action" "$service_id" "$lookup" ;;
    gpu_cloud) exec "$_self_dir/gpu_cloud_stack.sh" "$action" "$service_id" "$lookup" ;;
    *) "$_python" - "$service_id" "$provider" "$helper" <<'PY'
import json,sys
sid, provider, helper=sys.argv[1:4]
print(json.dumps({"schema":"queuebash.cloud_infra.action.v1","service_id":sid,"provider":provider,"helper":helper,"action":"unknown","decision":"deny","reason":"unsupported_helper","registry_checked":True,"fail_closed":True,"mutated":False}, sort_keys=True))
PY
      return 5 ;;
  esac
}

case "${1:-help}" in
  help|-h|--help)
    cat <<'USAGE'
Usage:
  providers.d/cloud_infra/cloud_infra.sh list
  providers.d/cloud_infra/cloud_infra.sh explain SERVICE
  providers.d/cloud_infra/cloud_infra.sh plan SERVICE start|stop|status
  providers.d/cloud_infra/cloud_infra.sh start SERVICE
  providers.d/cloud_infra/cloud_infra.sh stop SERVICE
  providers.d/cloud_infra/cloud_infra.sh status SERVICE

Environment:
  QUEUEBASH_CLOUD_INFRA_REGISTRY=/path/to/registry.json
  QUEUEBASH_CLOUD_INFRA_LIVE=1        # required for live mutation
USAGE
    ;;
  list) _list_services ;;
  explain)
    [[ $# -ge 2 ]] || _json_error missing_service 2
    _read_service "$2" explain || true
    ;;
  plan)
    [[ $# -ge 3 ]] || _json_error missing_plan_args 2
    _dispatch_helper "$2" "plan-${3}" ;;
  start|stop|status)
    [[ $# -ge 2 ]] || _json_error missing_service 2
    _dispatch_helper "$2" "$1" ;;
  *) _json_error unsupported_cloud_infra_command 2 ;;
esac
