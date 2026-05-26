#!/usr/bin/env bash
# bashqueues asset plugin: VMware vSphere / ESXi checks via govc

queue_asset_facilities() {
    cat <<'FACILITIES'
vsphere:cluster_healthy	Check all hosts in a cluster are connected
vsphere:datastore_free	Check a datastore has at least N GB free
vsphere:host_connected	Check an ESXi host is connected and not in maintenance
vsphere:snapshot_exists	Check a named snapshot exists on a VM
vsphere:task_complete	Check no tasks matching a description are running on a VM
vsphere:vm_exists	Check a VM path exists in the vCenter inventory
vsphere:vm_not_running	Check a vSphere VM is powered off
vsphere:vm_running	Check a vSphere VM is in powered-on state
FACILITIES
}
queue_asset_hints() {
    cat <<'HINTS'
vsphere:vm_running	target=VM inventory path	params=govc_url= govc_user= govc_password= timeout=10	example=queue_class_shared_asset vsphere vm_running "/dc/vm/app01"	notes=Blocks unless govc reports VirtualMachineSummary.Runtime.PowerState poweredOn.
vsphere:vm_not_running	target=VM inventory path	params=govc_url= govc_user= govc_password= timeout=10	example=queue_class_shared_asset vsphere vm_not_running "/dc/vm/app01"	notes=Anti-prerequisite. Blocks when the VM is powered on.
vsphere:vm_exists	target=VM inventory path	params=govc_url= govc_user= govc_password= timeout=10	example=queue_class_shared_asset vsphere vm_exists "/dc/vm/app01"	notes=Blocks unless the VM path exists.
vsphere:host_connected	target=ESXi host FQDN or IP	params=govc_url= govc_user= govc_password= timeout=10	example=queue_class_shared_asset vsphere host_connected "esxi-01.example.com"	notes=Blocks unless the host is connected and not in maintenance mode.
vsphere:datastore_free	target=datastore name	params=min_gb=50 govc_url= govc_user= govc_password= timeout=10	example=queue_class_shared_asset vsphere datastore_free "VSANSTORE01" min_gb=100	notes=Blocks unless datastore free bytes meet min_gb.
vsphere:snapshot_exists	target=VM inventory path	params=snapshot=NAME govc_url= govc_user= govc_password= timeout=10	example=queue_class_shared_asset vsphere snapshot_exists "/dc/vm/app01" snapshot=pre-change	notes=Blocks unless the snapshot tree contains the named snapshot.
vsphere:task_complete	target=VM inventory path	params=task_description= govc_url= govc_user= govc_password= timeout=10	example=queue_class_shared_asset vsphere task_complete "/dc/vm/app01" task_description=RelocateVM	notes=Blocks if govc task list contains a matching running task.
vsphere:cluster_healthy	target=cluster name	params=govc_url= govc_user= govc_password= timeout=15	example=queue_class_shared_asset vsphere cluster_healthy "Production"	notes=Blocks if cluster host usage output indicates disconnected or not responding hosts.
HINTS
}
queue_asset_param() { local key="$1"; shift || true; local p; for p in "$@"; do case "$p" in "$key="*) printf '%s\n' "${p#*=}"; return 0;; esac; done; return 1; }
_vsphere_need() { command -v govc >/dev/null 2>&1 || { echo 'asset_check_blocked: vsphere tool_missing=govc'; return 1; }; }
_vsphere_env() { local u user pass; u="$(queue_asset_param govc_url "$@" || true)"; user="$(queue_asset_param govc_user "$@" || true)"; pass="$(queue_asset_param govc_password "$@" || true)"; [[ -n "$u" ]] && export GOVC_URL="$u"; [[ -n "$user" ]] && export GOVC_USERNAME="$user"; [[ -n "$pass" ]] && export GOVC_PASSWORD="$pass"; }
_vsphere_timeout() { queue_asset_param timeout "$@" || echo 10; }
_vsphere_vm_power() { local vm="$1"; shift || true; _vsphere_env "$@"; timeout "$(_vsphere_timeout "$@")" govc vm.info -json "$vm" 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); v=d.get("VirtualMachines",[{}])[0]; print(v.get("Summary",{}).get("Runtime",{}).get("PowerState",""))' 2>/dev/null || true; }
queue_asset_check_vsphere_vm_running() { local token="$1" vm="$2"; shift 2 || true; _vsphere_need || return 1; local p; p="$(_vsphere_vm_power "$vm" "$@")"; [[ "$p" == poweredOn ]] && { echo "asset_check_ok: $token"; return 0; }; echo "asset_check_blocked: vsphere:vm_running vm=$vm power_state=${p:-unknown}"; return 1; }
queue_asset_check_vsphere_vm_not_running() { local token="$1" vm="$2"; shift 2 || true; _vsphere_need || return 1; local p; p="$(_vsphere_vm_power "$vm" "$@")"; [[ "$p" != poweredOn ]] && { echo "asset_check_ok: $token"; return 0; }; echo "asset_check_blocked: vsphere:vm_not_running vm=$vm power_state=$p"; return 1; }
queue_asset_check_vsphere_vm_exists() { local token="$1" vm="$2"; shift 2 || true; _vsphere_need || return 1; _vsphere_env "$@"; if timeout "$(_vsphere_timeout "$@")" govc vm.info "$vm" >/dev/null 2>&1; then echo "asset_check_ok: $token"; return 0; fi; echo "asset_check_blocked: vsphere:vm_exists vm=$vm"; return 1; }
queue_asset_check_vsphere_host_connected() { local token="$1" host="$2"; shift 2 || true; _vsphere_need || return 1; _vsphere_env "$@"; local out ok; out="$(timeout "$(_vsphere_timeout "$@")" govc host.info -json "$host" 2>/dev/null || true)"; ok="$(printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); h=d.get("HostSystems",[{}])[0]; r=h.get("Summary",{}).get("Runtime",{}); print("yes" if r.get("ConnectionState")=="connected" and not r.get("InMaintenanceMode", True) else "no")' 2>/dev/null || echo no)"; [[ "$ok" == yes ]] && { echo "asset_check_ok: $token"; return 0; }; echo "asset_check_blocked: vsphere:host_connected host=$host"; return 1; }
queue_asset_check_vsphere_datastore_free() { local token="$1" ds="$2"; shift 2 || true; _vsphere_need || return 1; _vsphere_env "$@"; local min free; min="$(queue_asset_param min_gb "$@" || echo 50)"; free="$(timeout "$(_vsphere_timeout "$@")" govc datastore.info -json "$ds" 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("Datastores",[{}])[0].get("Summary",{}).get("FreeSpace",0))' 2>/dev/null || echo 0)"; [[ "$free" =~ ^[0-9]+$ ]] || free=0; (( free >= min * 1073741824 )) && { echo "asset_check_ok: $token"; return 0; }; echo "asset_check_blocked: vsphere:datastore_free datastore=$ds free_bytes=$free min_gb=$min"; return 1; }
queue_asset_check_vsphere_snapshot_exists() { local token="$1" vm="$2"; shift 2 || true; _vsphere_need || return 1; _vsphere_env "$@"; local snap; snap="$(queue_asset_param snapshot "$@" || true)"; [[ -n "$snap" ]] || { echo 'asset_check_blocked: vsphere:snapshot_exists requires snapshot='; return 1; }; if timeout "$(_vsphere_timeout "$@")" govc snapshot.tree -vm "$vm" 2>/dev/null | grep -Fq -- "$snap"; then echo "asset_check_ok: $token"; return 0; fi; echo "asset_check_blocked: vsphere:snapshot_exists vm=$vm snapshot=$snap"; return 1; }
queue_asset_check_vsphere_task_complete() { local token="$1" vm="$2"; shift 2 || true; _vsphere_need || return 1; _vsphere_env "$@"; local desc out; desc="$(queue_asset_param task_description "$@" || true)"; out="$(timeout "$(_vsphere_timeout "$@")" govc tasks 2>/dev/null || true)"; [[ -n "$desc" && "$out" == *"$desc"* && "$out" == *"running"* ]] && { echo "asset_check_blocked: vsphere:task_complete vm=$vm task=$desc"; return 1; }; echo "asset_check_ok: $token"; }
queue_asset_check_vsphere_cluster_healthy() { local token="$1" cluster="$2"; shift 2 || true; _vsphere_need || return 1; _vsphere_env "$@"; local out; out="$(timeout "$(queue_asset_param timeout "$@" || echo 15)" govc cluster.usage -json "$cluster" 2>/dev/null || true)"; if grep -Eqi 'notresponding|disconnected|red' <<<"$out"; then echo "asset_check_blocked: vsphere:cluster_healthy cluster=$cluster"; return 1; fi; [[ -n "$out" ]] && { echo "asset_check_ok: $token"; return 0; }; echo "asset_check_blocked: vsphere:cluster_healthy cluster=$cluster unreadable"; return 1; }
