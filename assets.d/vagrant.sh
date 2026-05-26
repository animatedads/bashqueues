#!/usr/bin/env bash
# bashqueues asset plugin: Vagrant checks

queue_asset_facilities() {
    cat <<'FACILITIES'
vagrant:box_exists	Check a named Vagrant box is installed locally
vagrant:box_outdated	Check if a box has an update available
vagrant:exists	Check a Vagrant machine has been created
vagrant:not_running	Check a Vagrant machine is not running
vagrant:running	Check a Vagrant machine is in running state
FACILITIES
}
queue_asset_hints() {
    cat <<'HINTS'
vagrant:running	target=machine name	params=cwd=/path/to/vagrantfile/dir timeout=10	example=queue_class_shared_asset vagrant running "default" cwd=/opt/vms/test	notes=Blocks unless vagrant status reports the machine running.
vagrant:not_running	target=machine name	params=cwd=/path/to/vagrantfile/dir timeout=10	example=queue_class_shared_asset vagrant not_running "default" cwd=/opt/vms/build	notes=Anti-prerequisite. Passes when the machine is not running.
vagrant:exists	target=machine name	params=cwd=/path/to/vagrantfile/dir timeout=10	example=queue_class_shared_asset vagrant exists "default" cwd=/opt/vms/build	notes=Blocks when the machine state is not_created.
vagrant:box_exists	target=box name	params=timeout=10	example=queue_class_shared_asset vagrant box_exists "ubuntu/jammy64"	notes=Blocks unless the named Vagrant box is installed locally.
vagrant:box_outdated	target=box name	params=timeout=30	example=queue_class_shared_asset vagrant box_outdated "ubuntu/jammy64"	notes=Refresh-gate. May contact registry and is intentionally slower than normal preflight checks.
HINTS
}
queue_asset_param() { local key="$1"; shift || true; local p; for p in "$@"; do case "$p" in "$key="*) printf '%s\n' "${p#*=}"; return 0;; esac; done; return 1; }
_vagrant_need() { command -v vagrant >/dev/null 2>&1 || { echo 'asset_check_blocked: vagrant tool_missing=vagrant'; return 1; }; }
_vagrant_state() { local name="$1"; shift || true; local cwd to; cwd="$(queue_asset_param cwd "$@" || pwd)"; to="$(queue_asset_param timeout "$@" || echo 10)"; (cd "$cwd" 2>/dev/null && timeout "$to" vagrant status "$name" --machine-readable 2>/dev/null) | awk -F, -v n="$name" '$2==n && $3=="state" {print $4; exit}'; }
queue_asset_check_vagrant_running() { local token="$1" name="$2"; shift 2 || true; _vagrant_need || return 1; local st; st="$(_vagrant_state "$name" "$@")"; [[ "$st" == running ]] && { echo "asset_check_ok: $token"; return 0; }; echo "asset_check_blocked: vagrant:running machine=$name state=${st:-unknown}"; return 1; }
queue_asset_check_vagrant_not_running() { local token="$1" name="$2"; shift 2 || true; _vagrant_need || return 1; local st; st="$(_vagrant_state "$name" "$@")"; [[ "$st" != running ]] && { echo "asset_check_ok: $token"; return 0; }; echo "asset_check_blocked: vagrant:not_running machine=$name state=$st"; return 1; }
queue_asset_check_vagrant_exists() { local token="$1" name="$2"; shift 2 || true; _vagrant_need || return 1; local st; st="$(_vagrant_state "$name" "$@")"; [[ -n "$st" && "$st" != not_created ]] && { echo "asset_check_ok: $token"; return 0; }; echo "asset_check_blocked: vagrant:exists machine=$name state=${st:-unknown}"; return 1; }
queue_asset_check_vagrant_box_exists() { local token="$1" box="$2"; shift 2 || true; _vagrant_need || return 1; local to; to="$(queue_asset_param timeout "$@" || echo 10)"; if timeout "$to" vagrant box list --machine-readable 2>/dev/null | grep -Fq ",$box,"; then echo "asset_check_ok: $token"; return 0; fi; echo "asset_check_blocked: vagrant:box_exists box=$box"; return 1; }
queue_asset_check_vagrant_box_outdated() { local token="$1" box="$2"; shift 2 || true; _vagrant_need || return 1; local to out; to="$(queue_asset_param timeout "$@" || echo 30)"; out="$(timeout "$to" vagrant box outdated --global --machine-readable 2>/dev/null || true)"; grep -Fq "$box" <<<"$out" && { echo "asset_check_ok: $token"; return 0; }; echo "asset_check_blocked: vagrant:box_outdated no_update_or_missing box=$box"; return 1; }
