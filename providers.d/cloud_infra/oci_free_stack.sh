#!/usr/bin/env bash
# VM.Standard.E2.1.Micro is the default Always Free-compatible shape used by registry examples.
set -euo pipefail

_action="${1:-help}"
_service_id="${2:-}"
_lookup_json="${3:-}"
_python="${QUEUEBASH_PYTHON:-/usr/bin/python3}"
_live="${QUEUEBASH_CLOUD_INFRA_LIVE:-0}"
_oci_bin="${QUEUEBASH_OCI_CLI:-oci}"

_emit() {
  local decision="$1" reason="$2" mutated="${3:-false}" extra="${4:-{}}"
  "$_python" - "$_lookup_json" "$_action" "$_live" "$decision" "$reason" "$mutated" "$extra" <<'PY'
import json, sys
lookup_s, action, live, decision, reason, mutated_s, extra_s = sys.argv[1:8]
lookup=json.loads(lookup_s) if lookup_s else {"service":{}}
svc=lookup.get("service", {})
try:
    extra=json.loads(extra_s)
except Exception:
    extra={}
out={
  "schema":"queuebash.cloud_infra.action.v1",
  "provider":"oci",
  "helper":"oci_free",
  "service_id":svc.get("id"),
  "action":action,
  "decision":decision,
  "reason":reason,
  "registry_checked":bool(lookup.get("registry_checked")),
  "live": live == "1",
  "mutated": mutated_s == "true",
  "fail_closed": decision in ("deny","error"),
  "region":svc.get("region"),
  "shape":svc.get("shape"),
  "prefix":svc.get("prefix"),
  "instance_id":svc.get("instance_id"),
  "legal":svc.get("legal", {}),
}
out.update(extra)
print(json.dumps(out, sort_keys=True))
PY
}

_service_field() {
  local field="$1"
  printf '%s\n' "$_lookup_json" | "$_python" -c 'import json,sys; d=json.load(sys.stdin).get("service",{}); print(d.get(sys.argv[1],""))' "$field"
}

_service_bool() {
  local field="$1"
  printf '%s\n' "$_lookup_json" | "$_python" -c 'import json,sys; v=json.load(sys.stdin).get("service",{}).get(sys.argv[1],False); print("1" if v is True else "0")' "$field"
}

_discover_compartment() {
  local cfg="${OCI_CLI_CONFIG_FILE:-$HOME/.oci/config}"
  [[ -f "$cfg" ]] || return 1
  local cid
  cid="$(grep -m 1 -iE '^[[:space:]]*compartment-id[[:space:]]*=' "$cfg" | cut -d'=' -f2 | tr -d ' \r\n"' || true)"
  if [[ -z "$cid" ]]; then
    cid="$(grep -m 1 -iE '^[[:space:]]*tenancy[[:space:]]*=' "$cfg" | cut -d'=' -f2 | tr -d ' \r\n"' || true)"
  fi
  [[ -n "$cid" ]] || return 1
  printf '%s\n' "$cid"
}

_discover_pubkey() {
  find "$HOME/.oci" -maxdepth 1 -name "*.pub" 2>/dev/null | head -n 1
}

_live_start_or_create() {
  local instance_id="$1" compartment_id="$2" ssh_pub="$3"
  local prefix shape vcn_cidr subnet_cidr os os_version
  prefix="$(_service_field prefix)"; shape="$(_service_field shape)"
  vcn_cidr="$(_service_field vcn_cidr)"; subnet_cidr="$(_service_field subnet_cidr)"
  os="$(_service_field os)"; os_version="$(_service_field os_version)"
  if [[ -n "$instance_id" ]]; then
    "$_oci_bin" compute instance action --action START --instance-id "$instance_id" --wait-for-state RUNNING >/dev/null
    _emit allow instance_started true "{\"instance_id\":\"$instance_id\"}"
    return 0
  fi
  [[ "$(_service_bool allow_create)" == "1" ]] || { _emit deny create_not_allowed false; return 4; }
  local ad image_id vcn_id igw_id rt_id sl_id subnet_id new_instance vnic_attachment_id vnic_id public_ip
  ad="$($_oci_bin iam availability-domain list -c "$compartment_id" --query 'data[0].name' --raw-output)"
  image_id="$($_oci_bin compute image list -c "$compartment_id" --operating-system "$os" --operating-system-version "$os_version" --shape "$shape" --sort-by TIMECREATED --sort-order DESC --query 'data[0].id' --raw-output)"
  vcn_id="$($_oci_bin network vcn create -c "$compartment_id" --cidr-block "$vcn_cidr" --display-name "${prefix}-vcn" --dns-label "lonfree" --wait-for-state AVAILABLE --query 'data.id' --raw-output)"
  igw_id="$($_oci_bin network internet-gateway create -c "$compartment_id" --vcn-id "$vcn_id" --is-enabled true --display-name "${prefix}-igw" --wait-for-state AVAILABLE --query 'data.id' --raw-output)"
  local route_rules='[{"networkEntityId":"'$igw_id'","destination":"0.0.0.0/0","destinationType":"CIDR_BLOCK"}]'
  rt_id="$($_oci_bin network route-table create -c "$compartment_id" --vcn-id "$vcn_id" --display-name "${prefix}-rt" --route-rules "$route_rules" --wait-for-state AVAILABLE --query 'data.id' --raw-output)"
  local egress='[{"destination":"0.0.0.0/0","protocol":"all","isStateless":false}]'
  local ingress='[{"source":"0.0.0.0/0","protocol":"6","isStateless":false,"tcpOptions":{"destinationPortRange":{"max":22,"min":22}}}]'
  sl_id="$($_oci_bin network security-list create -c "$compartment_id" --vcn-id "$vcn_id" --display-name "${prefix}-sl" --egress-security-rules "$egress" --ingress-security-rules "$ingress" --wait-for-state AVAILABLE --query 'data.id' --raw-output)"
  subnet_id="$($_oci_bin network subnet create -c "$compartment_id" --vcn-id "$vcn_id" --cidr-block "$subnet_cidr" --display-name "${prefix}-public-subnet" --route-table-id "$rt_id" --security-list-ids '["'$sl_id'"]' --availability-domain "$ad" --wait-for-state AVAILABLE --query 'data.id' --raw-output)"
  new_instance="$($_oci_bin compute instance launch -c "$compartment_id" --availability-domain "$ad" --shape "$shape" --subnet-id "$subnet_id" --assign-public-ip true --display-name "${prefix}-instance" --image-id "$image_id" --ssh-authorized-keys-file "$ssh_pub" --wait-for-state RUNNING --query 'data.id' --raw-output)"
  vnic_attachment_id="$($_oci_bin compute vnic-attachment list -c "$compartment_id" --instance-id "$new_instance" --query 'data[0].id' --raw-output)"
  vnic_id="$($_oci_bin compute vnic-attachment get --vnic-attachment-id "$vnic_attachment_id" --query 'data."vnic-id"' --raw-output)"
  public_ip="$($_oci_bin network vnic get --vnic-id "$vnic_id" --query 'data."public-ip"' --raw-output)"
  "$_python" - "$new_instance" "$public_ip" <<'PY'
import json,sys
print(json.dumps({"instance_id":sys.argv[1],"public_ip":sys.argv[2],"note":"registry_state_should_be_reviewed_and_persisted_by_operator"}, sort_keys=True))
PY
}

case "$_action" in
  plan-start|plan-stop|plan-status)
    _emit dry_run live_gate_not_enabled false "{\"planned_only\":true,\"commands\":[\"registry lookup\",\"oci cli action gated by QUEUEBASH_CLOUD_INFRA_LIVE=1\"]}"
    ;;
  status)
    instance_id="$(_service_field instance_id)"
    if [[ "$_live" != "1" ]]; then
      _emit dry_run live_gate_not_enabled false "{\"instance_id\":\"$instance_id\",\"status\":\"unknown_without_live_check\"}"
      exit 0
    fi
    [[ -n "$instance_id" ]] || { _emit deny missing_instance_id_for_status false; exit 4; }
    state="$($_oci_bin compute instance get --instance-id "$instance_id" --query 'data."lifecycle-state"' --raw-output)"
    _emit allow status_observed false "{\"instance_id\":\"$instance_id\",\"oci_state\":\"$state\"}"
    ;;
  start)
    if [[ "$_live" != "1" ]]; then
      _emit dry_run live_gate_not_enabled false "{\"commands\":[\"discover compartment from OCI config\",\"discover SSH public key under ~/.oci\",\"create or start OCI Always Free stack\"]}"
      exit 0
    fi
    command -v "$_oci_bin" >/dev/null 2>&1 || { _emit deny oci_cli_not_found false; exit 4; }
    compartment="$(_discover_compartment)" || { _emit deny compartment_not_found false; exit 4; }
    ssh_pub="$(_discover_pubkey)" || true
    [[ -n "$ssh_pub" ]] || { _emit deny ssh_public_key_not_found false; exit 4; }
    instance_id="$(_service_field instance_id)"
    _live_start_or_create "$instance_id" "$compartment" "$ssh_pub"
    ;;
  stop)
    instance_id="$(_service_field instance_id)"
    [[ -n "$instance_id" ]] || { _emit deny missing_instance_id_for_stop false; exit 4; }
    if [[ "$_live" != "1" ]]; then
      _emit dry_run live_gate_not_enabled false "{\"instance_id\":\"$instance_id\",\"commands\":[\"oci compute instance action --action STOP --instance-id <redacted>\"]}"
      exit 0
    fi
    command -v "$_oci_bin" >/dev/null 2>&1 || { _emit deny oci_cli_not_found false; exit 4; }
    "$_oci_bin" compute instance action --action STOP --instance-id "$instance_id" --wait-for-state STOPPED >/dev/null
    _emit allow instance_stopped true "{\"instance_id\":\"$instance_id\"}"
    ;;
  *)
    _emit deny unsupported_oci_free_action false
    exit 2
    ;;
esac
