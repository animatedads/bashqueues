#!/usr/bin/env bash
# bashqueues asset plugin: libvirt/KVM VM checks

queue_asset_facilities() {
    cat <<'FACILITIES'
vm:disk_age	Check a QEMU disk image was modified within N hours
vm:disk_available	Check a QEMU disk image path exists and is accessible
vm:disk_format	Check a QEMU disk image is in the expected format
vm:exists	Check a libvirt domain exists in any state
vm:net_active	Check a libvirt network is active
vm:not_running	Check a libvirt domain is not running
vm:pool_active	Check a libvirt storage pool is active
vm:running	Check a libvirt domain is in running state
vm:snapshot_exists	Check a named snapshot exists for a domain
vm:vcpu_count	Check domain vCPU count is within expected range
FACILITIES
}

queue_asset_hints() {
    cat <<'HINTS'
vm:running	target=domain name	params=connect=qemu:///system timeout=5	example=queue_class_shared_asset vm running "prod-db-01"	notes=Blocks unless virsh reports the domain state as running.
vm:not_running	target=domain name	params=connect=qemu:///system timeout=5	example=queue_class_shared_asset vm not_running "build-worker-01"	notes=Anti-prerequisite. Passes when the domain is shut off or absent.
vm:exists	target=domain name	params=connect=qemu:///system timeout=5	example=queue_class_shared_asset vm exists "prod-db-01"	notes=Blocks unless the libvirt domain exists.
vm:snapshot_exists	target=domain name	params=snapshot=NAME connect=qemu:///system timeout=5	example=queue_class_shared_asset vm snapshot_exists "staging-01" snapshot=pre-migration	notes=Blocks unless the named snapshot exists for the domain.
vm:disk_available	target=disk image path	params=readable=1 writable=0	example=queue_class_shared_asset vm disk_available "/var/lib/libvirt/images/vm.qcow2" readable=1	notes=Checks that a disk image path exists and has requested access permissions.
vm:disk_format	target=disk image path	params=format=qcow2 tool=qemu-img timeout=5	example=queue_class_shared_asset vm disk_format "/var/lib/libvirt/images/vm.qcow2" format=qcow2	notes=Uses qemu-img info --output=json and blocks on unexpected format.
vm:disk_age	target=disk image path	params=max_hours=24	example=queue_class_shared_asset vm disk_age "/backups/vm.qcow2" max_hours=24	notes=Blocks if the disk image modification time is older than max_hours.
vm:pool_active	target=pool name	params=connect=qemu:///system timeout=5	example=queue_class_shared_asset vm pool_active "default"	notes=Blocks unless virsh reports the storage pool state as running.
vm:net_active	target=network name	params=connect=qemu:///system timeout=5	example=queue_class_shared_asset vm net_active "default"	notes=Blocks unless virsh reports the libvirt network as active.
vm:vcpu_count	target=domain name	params=min=1 max=64 connect=qemu:///system timeout=5	example=queue_class_shared_asset vm vcpu_count "builder" min=2 max=16	notes=Blocks unless the configured vCPU count falls within range.
HINTS
}

queue_asset_param() { local key="$1"; shift || true; local p; for p in "$@"; do case "$p" in "$key="*) printf '%s\n' "${p#*=}"; return 0;; esac; done; return 1; }
_vm_connect() { queue_asset_param connect "$@" || echo 'qemu:///system'; }
_vm_timeout() { queue_asset_param timeout "$@" || echo 5; }
_vm_need_virsh() { command -v virsh >/dev/null 2>&1 || { echo 'asset_check_blocked: vm tool_missing=virsh'; return 1; }; }

queue_asset_check_vm_running() {
    local token="$1" dom="$2"; shift 2 || true; _vm_need_virsh || return 1
    local st; st="$(timeout "$(_vm_timeout "$@")" virsh --connect="$(_vm_connect "$@")" domstate "$dom" 2>/dev/null || true)"
    [[ "$st" == running ]] && { echo "asset_check_ok: $token"; return 0; }
    echo "asset_check_blocked: vm:running domain=$dom state=${st:-unknown}"; return 1
}
queue_asset_check_vm_not_running() {
    local token="$1" dom="$2"; shift 2 || true; _vm_need_virsh || return 1
    local st rc; st="$(timeout "$(_vm_timeout "$@")" virsh --connect="$(_vm_connect "$@")" domstate "$dom" 2>/dev/null)"; rc=$?
    [[ $rc -ne 0 || "$st" == 'shut off' || "$st" != running ]] && { echo "asset_check_ok: $token"; return 0; }
    echo "asset_check_blocked: vm:not_running domain=$dom state=$st"; return 1
}
queue_asset_check_vm_exists() {
    local token="$1" dom="$2"; shift 2 || true; _vm_need_virsh || return 1
    if timeout "$(_vm_timeout "$@")" virsh --connect="$(_vm_connect "$@")" dominfo "$dom" >/dev/null 2>&1; then echo "asset_check_ok: $token"; return 0; fi
    echo "asset_check_blocked: vm:exists missing domain=$dom"; return 1
}
queue_asset_check_vm_snapshot_exists() {
    local token="$1" dom="$2"; shift 2 || true; _vm_need_virsh || return 1
    local snap; snap="$(queue_asset_param snapshot "$@" || true)"; [[ -n "$snap" ]] || { echo 'asset_check_blocked: vm:snapshot_exists requires snapshot='; return 1; }
    if timeout "$(_vm_timeout "$@")" virsh --connect="$(_vm_connect "$@")" snapshot-list --name "$dom" 2>/dev/null | grep -Fxq -- "$snap"; then echo "asset_check_ok: $token"; return 0; fi
    echo "asset_check_blocked: vm:snapshot_exists domain=$dom snapshot=$snap"; return 1
}
queue_asset_check_vm_disk_available() {
    local token="$1" path="$2"; shift 2 || true
    local readable writable; readable="$(queue_asset_param readable "$@" || echo 1)"; writable="$(queue_asset_param writable "$@" || echo 0)"
    [[ -e "$path" ]] || { echo "asset_check_blocked: vm:disk_available missing path=$path"; return 1; }
    [[ "$readable" != 1 || -r "$path" ]] || { echo "asset_check_blocked: vm:disk_available not_readable path=$path"; return 1; }
    [[ "$writable" != 1 || -w "$path" ]] || { echo "asset_check_blocked: vm:disk_available not_writable path=$path"; return 1; }
    echo "asset_check_ok: $token"
}
queue_asset_check_vm_disk_format() {
    local token="$1" path="$2"; shift 2 || true
    local want tool to got; want="$(queue_asset_param format "$@" || echo qcow2)"; tool="$(queue_asset_param tool "$@" || echo qemu-img)"; to="$(_vm_timeout "$@")"
    command -v "$tool" >/dev/null 2>&1 || { echo "asset_check_blocked: vm:disk_format tool_missing=$tool"; return 1; }
    [[ -e "$path" ]] || { echo "asset_check_blocked: vm:disk_format missing path=$path"; return 1; }
    got="$(timeout "$to" "$tool" info --output=json "$path" 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("format",""))' 2>/dev/null || true)"
    [[ -z "$got" ]] && got="$(timeout "$to" "$tool" info "$path" 2>/dev/null | awk -F': ' '/file format/ {print $2; exit}')"
    [[ "$got" == "$want" ]] && { echo "asset_check_ok: $token"; return 0; }
    echo "asset_check_blocked: vm:disk_format path=$path expected=$want got=${got:-unknown}"; return 1
}
queue_asset_check_vm_disk_age() {
    local token="$1" path="$2"; shift 2 || true
    local max mt now age; max="$(queue_asset_param max_hours "$@" || echo 24)"; [[ "$max" =~ ^[0-9]+$ ]] || { echo "asset_check_blocked: vm:disk_age invalid max_hours=$max"; return 1; }
    [[ -e "$path" ]] || { echo "asset_check_blocked: vm:disk_age missing path=$path"; return 1; }
    mt="$(stat -c %Y -- "$path" 2>/dev/null || true)"; now="$(date +%s)"; age=$(( (now - mt) / 3600 ))
    (( age <= max )) && { echo "asset_check_ok: $token"; return 0; }
    echo "asset_check_blocked: vm:disk_age path=$path age_hours=$age max_hours=$max"; return 1
}
queue_asset_check_vm_pool_active() {
    local token="$1" pool="$2"; shift 2 || true; _vm_need_virsh || return 1
    if timeout "$(_vm_timeout "$@")" virsh --connect="$(_vm_connect "$@")" pool-info "$pool" 2>/dev/null | grep -qi 'State:.*running'; then echo "asset_check_ok: $token"; return 0; fi
    echo "asset_check_blocked: vm:pool_active pool=$pool"; return 1
}
queue_asset_check_vm_net_active() {
    local token="$1" net="$2"; shift 2 || true; _vm_need_virsh || return 1
    if timeout "$(_vm_timeout "$@")" virsh --connect="$(_vm_connect "$@")" net-info "$net" 2>/dev/null | grep -qi 'Active:.*yes'; then echo "asset_check_ok: $token"; return 0; fi
    echo "asset_check_blocked: vm:net_active network=$net"; return 1
}
queue_asset_check_vm_vcpu_count() {
    local token="$1" dom="$2"; shift 2 || true; _vm_need_virsh || return 1
    local min max n; min="$(queue_asset_param min "$@" || echo 1)"; max="$(queue_asset_param max "$@" || echo 64)"
    n="$(timeout "$(_vm_timeout "$@")" virsh --connect="$(_vm_connect "$@")" dominfo "$dom" 2>/dev/null | awk -F: '/^CPU\(s\)/ {gsub(/ /,"",$2); print $2; exit}')"
    [[ "$n" =~ ^[0-9]+$ ]] || { echo "asset_check_blocked: vm:vcpu_count unreadable domain=$dom"; return 1; }
    (( n >= min && n <= max )) && { echo "asset_check_ok: $token"; return 0; }
    echo "asset_check_blocked: vm:vcpu_count domain=$dom count=$n min=$min max=$max"; return 1
}
