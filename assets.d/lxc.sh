#!/usr/bin/env bash
# bashqueues asset plugin: LXC/LXD checks

queue_asset_facilities() {
    cat <<'FACILITIES'
lxc:exists	Check a named LXC/LXD container exists
lxc:healthy	Check a named LXC/LXD container is running and not frozen
lxc:image_exists	Check a named LXD image fingerprint or alias exists
lxc:not_running	Check a named LXC/LXD container is not running
lxc:profile_exists	Check a named LXD profile exists
lxc:running	Check a named LXC/LXD container is running
lxc:storage_pool_ok	Check a named LXD storage pool is in OK state
FACILITIES
}

queue_asset_hints() {
    cat <<'HINTS'
lxc:running	target=container name	params=tool=lxc|lxc-info remote=local timeout=5	example=queue_class_shared_asset lxc running "prod-app-01"	notes=Blocks unless the LXC/LXD container is running.
lxc:not_running	target=container name	params=tool=lxc|lxc-info remote=local timeout=5	example=queue_class_shared_asset lxc not_running "build-worker-01"	notes=Anti-prerequisite. Passes when the container is stopped or absent.
lxc:exists	target=container name	params=remote=local timeout=5	example=queue_class_shared_asset lxc exists "prod-app-01"	notes=Blocks unless the container exists in any state.
lxc:healthy	target=container name	params=remote=local timeout=5	example=queue_class_shared_asset lxc healthy "prod-app-01"	notes=Blocks unless the container is running and not frozen.
lxc:image_exists	target=image alias or fingerprint prefix	params=remote=local timeout=5	example=queue_class_shared_asset lxc image_exists "ubuntu/22.04/amd64"	notes=Blocks unless a matching LXD image alias or fingerprint exists.
lxc:profile_exists	target=profile name	params=remote=local timeout=5	example=queue_class_shared_asset lxc profile_exists "default"	notes=Blocks unless the named LXD profile exists.
lxc:storage_pool_ok	target=pool name	params=remote=local timeout=5	example=queue_class_shared_asset lxc storage_pool_ok "local"	notes=Blocks unless the LXD storage pool exists and is created.
HINTS
}

queue_asset_param() { local key="$1"; shift || true; local p; for p in "$@"; do case "$p" in "$key="*) printf '%s\n' "${p#*=}"; return 0;; esac; done; return 1; }
_lxc_tool() { local want; want="$(queue_asset_param tool "$@" || true)"; if [[ -n "$want" ]]; then command -v "$want" >/dev/null 2>&1 || { echo "asset_check_blocked: lxc tool_missing=$want"; return 1; }; echo "$want"; return 0; fi; command -v lxc >/dev/null 2>&1 && { echo lxc; return 0; }; command -v lxc-info >/dev/null 2>&1 && { echo lxc-info; return 0; }; echo 'asset_check_blocked: lxc tool_missing=lxc|lxc-info'; return 1; }
_lxc_ref() { local name="$1" remote="$2"; [[ "$remote" == local || -z "$remote" ]] && echo "$name" || echo "$remote:$name"; }
_lxc_status() { local tool="$1" name="$2"; shift 2 || true; local remote to ref; remote="$(queue_asset_param remote "$@" || echo local)"; to="$(queue_asset_param timeout "$@" || echo 5)"; if [[ "$tool" == lxc ]]; then ref="$(_lxc_ref "$name" "$remote")"; timeout "$to" lxc list "$ref" --format=csv -c s 2>/dev/null | head -n1; else timeout "$to" lxc-info -n "$name" -sH 2>/dev/null; fi; }
queue_asset_check_lxc_running() { local token="$1" name="$2"; shift 2 || true; local tool st; tool="$(_lxc_tool "$@")" || { echo "$tool"; return 1; }; st="$(_lxc_status "$tool" "$name" "$@")"; [[ "$st" =~ ^(Running|RUNNING)$ ]] && { echo "asset_check_ok: $token"; return 0; }; echo "asset_check_blocked: lxc:running name=$name status=${st:-unknown}"; return 1; }
queue_asset_check_lxc_not_running() { local token="$1" name="$2"; shift 2 || true; local tool st; tool="$(_lxc_tool "$@")" || { echo "$tool"; return 1; }; st="$(_lxc_status "$tool" "$name" "$@")"; [[ ! "$st" =~ ^(Running|RUNNING)$ ]] && { echo "asset_check_ok: $token"; return 0; }; echo "asset_check_blocked: lxc:not_running name=$name status=$st"; return 1; }
queue_asset_check_lxc_exists() { local token="$1" name="$2"; shift 2 || true; local tool st; tool="$(_lxc_tool "$@")" || { echo "$tool"; return 1; }; st="$(_lxc_status "$tool" "$name" "$@")"; [[ -n "$st" ]] && { echo "asset_check_ok: $token"; return 0; }; echo "asset_check_blocked: lxc:exists missing name=$name"; return 1; }
queue_asset_check_lxc_healthy() { local token="$1" name="$2"; shift 2 || true; local tool st; tool="$(_lxc_tool "$@")" || { echo "$tool"; return 1; }; st="$(_lxc_status "$tool" "$name" "$@")"; [[ "$st" =~ ^(Running|RUNNING)$ ]] && { echo "asset_check_ok: $token"; return 0; }; echo "asset_check_blocked: lxc:healthy name=$name status=${st:-unknown}"; return 1; }
queue_asset_check_lxc_image_exists() { local token="$1" image="$2"; shift 2 || true; command -v lxc >/dev/null 2>&1 || { echo 'asset_check_blocked: lxc:image_exists tool_missing=lxc'; return 1; }; local remote to; remote="$(queue_asset_param remote "$@" || echo local)"; to="$(queue_asset_param timeout "$@" || echo 5)"; if timeout "$to" lxc image list "$remote:" --format=csv -c lf 2>/dev/null | grep -q -- "$image"; then echo "asset_check_ok: $token"; return 0; fi; echo "asset_check_blocked: lxc:image_exists image=$image remote=$remote"; return 1; }
queue_asset_check_lxc_profile_exists() { local token="$1" prof="$2"; shift 2 || true; command -v lxc >/dev/null 2>&1 || { echo 'asset_check_blocked: lxc:profile_exists tool_missing=lxc'; return 1; }; local remote to; remote="$(queue_asset_param remote "$@" || echo local)"; to="$(queue_asset_param timeout "$@" || echo 5)"; if timeout "$to" lxc profile show "$prof" >/dev/null 2>&1; then echo "asset_check_ok: $token"; return 0; fi; echo "asset_check_blocked: lxc:profile_exists profile=$prof remote=$remote"; return 1; }
queue_asset_check_lxc_storage_pool_ok() { local token="$1" pool="$2"; shift 2 || true; command -v lxc >/dev/null 2>&1 || { echo 'asset_check_blocked: lxc:storage_pool_ok tool_missing=lxc'; return 1; }; local to; to="$(queue_asset_param timeout "$@" || echo 5)"; if timeout "$to" lxc storage show "$pool" 2>/dev/null | grep -q '^status: Created'; then echo "asset_check_ok: $token"; return 0; fi; echo "asset_check_blocked: lxc:storage_pool_ok pool=$pool"; return 1; }
