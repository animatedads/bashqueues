#!/usr/bin/env bash
# bashqueues Microsoft file services asset checks (SMB/CIFS)

_MSFS_TIMEOUT="${MSFS_TIMEOUT:-10}"

queue_asset_facilities() {
    cat <<'FACILITIES'
msfs:smb_mountable	Validates that an SMB/CIFS share can be mounted read-only
msfs:smb_permissions	Validates read/write access to an already mounted SMB path
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
msfs:smb_mountable	target=//server/share	params=user=... password=... mountpoint=/tmp/... timeout=10	example=queue_class_shared_asset msfs smb_mountable //fileserver/shared user=svc password=$SMB_PASSWORD	notes=Uses mount.cifs read-only and unmounts immediately. Requires suitable local mount permissions.
msfs:smb_permissions	target=/mnt/share/path	params=timeout=10	example=queue_class_shared_asset msfs smb_permissions /mnt/share/drop	notes=Creates, reads, and removes a small temporary file in the target directory.
EOF_HINTS
}

_queue_asset_msfs_param() { queue_asset_param "$@"; }

queue_asset_check_msfs_smb_mountable() {
    local token="$1" share="$2"; shift 2 || true
    local user password mountpoint timeout
    user="$(_queue_asset_msfs_param user "$@" || true)"
    password="$(_queue_asset_msfs_param password "$@" || true)"
    mountpoint="$(_queue_asset_msfs_param mountpoint "$@" || echo "/tmp/queuebash_smb_test.$$")"
    timeout="$(_queue_asset_msfs_param timeout "$@" || echo "$_MSFS_TIMEOUT")"
    if ! command -v mount.cifs >/dev/null 2>&1; then
        echo "asset_check_blocked: msfs:smb_mountable requires mount.cifs"
        return 1
    fi
    if [[ -z "$share" || -z "$user" || -z "$password" ]]; then
        echo "asset_check_blocked: msfs:smb_mountable requires target=//server/share user= password="
        return 1
    fi
    mkdir -p "$mountpoint" 2>/dev/null || true
    if timeout "$timeout" mount.cifs "$share" "$mountpoint" -o "username=$user,password=$password,ro" >/dev/null 2>&1; then
        umount "$mountpoint" >/dev/null 2>&1 || true
        rmdir "$mountpoint" >/dev/null 2>&1 || true
        echo "asset_check_ok: $token"
        return 0
    fi
    umount "$mountpoint" >/dev/null 2>&1 || true
    rmdir "$mountpoint" >/dev/null 2>&1 || true
    echo "asset_check_blocked: msfs:smb_mountable failed for $share"
    return 1
}

queue_asset_check_msfs_smb_permissions() {
    local token="$1" path="$2"; shift 2 || true
    local timeout testfile
    timeout="$(_queue_asset_msfs_param timeout "$@" || echo "$_MSFS_TIMEOUT")"
    testfile="$path/.queuebash_perm_test.$$"
    if [[ ! -d "$path" ]]; then
        echo "asset_check_blocked: msfs:smb_permissions path not a directory: $path"
        return 1
    fi
    if timeout "$timeout" bash -c 'printf test > "$1" && cat "$1" >/dev/null && rm -f "$1"' _ "$testfile" >/dev/null 2>&1; then
        echo "asset_check_ok: $token"
        return 0
    fi
    rm -f "$testfile" >/dev/null 2>&1 || true
    echo "asset_check_blocked: msfs:smb_permissions RW test failed in $path"
    return 1
}
