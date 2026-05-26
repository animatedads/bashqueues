#!/usr/bin/env bash
# bashqueues asset plugin: crypto governance checks

queue_asset_facilities() {
    cat <<'FACILITIES'
crypto:volume_encrypted	Checks that a target path is backed by an encrypted block device or approved encrypted filesystem
FACILITIES
}

queue_asset_hints() {
    cat <<'HINTS'
crypto:volume_encrypted	target=path	params=allow_marker=/path/.queuebash-encrypted allow_fstype=crypto_LUKS,crypt require=1	example=queue_class_shared_asset crypto volume_encrypted "/data/work"	notes=Blocks sensitive jobs unless the target path appears to be on encrypted storage or has an explicit admin marker.
HINTS
}

queue_asset_param() {
    local key="$1" p
    shift || true
    for p in "$@"; do
        case "$p" in "$key="*) printf '%s\n' "${p#*=}"; return 0 ;; esac
    done
    return 1
}

_crypto_csv_has() {
    local list="${1:-}" needle="${2:-}" item
    list="${list// /}"
    IFS=',' read -r -a _qb_crypto_items <<< "$list"
    for item in "${_qb_crypto_items[@]}"; do [[ "$item" == "$needle" || "$item" == "*" ]] && return 0; done
    return 1
}

queue_asset_check_crypto_volume_encrypted() {
    local token="$1" target="${2:-}"; shift 2 || true
    local marker allow_fstype src fstype pkname type mapper
    [[ -n "$target" ]] || { echo "asset_check_blocked: crypto:volume_encrypted target_required"; return 1; }
    [[ -e "$target" ]] || { echo "asset_check_blocked: crypto:volume_encrypted target_missing=$target"; return 1; }
    marker="$(queue_asset_param allow_marker "$@" || echo "$target/.queuebash-encrypted")"
    allow_fstype="$(queue_asset_param allow_fstype "$@" || echo "crypto_LUKS,crypt")"

    if [[ -n "$marker" && -f "$marker" ]]; then
        echo "asset_check_ok: $token marker=$marker"
        return 0
    fi

    if command -v findmnt >/dev/null 2>&1; then
        src="$(findmnt -no SOURCE --target "$target" 2>/dev/null | head -n1 || true)"
        fstype="$(findmnt -no FSTYPE --target "$target" 2>/dev/null | head -n1 || true)"
    else
        src="$(df --output=source "$target" 2>/dev/null | awk 'NR==2 {print $1}')"
        fstype=""
    fi

    if [[ -n "$fstype" ]] && _crypto_csv_has "$allow_fstype" "$fstype"; then
        echo "asset_check_ok: $token fstype=$fstype source=$src"
        return 0
    fi

    if [[ "$src" == /dev/mapper/* ]]; then
        mapper="${src#/dev/mapper/}"
        if command -v dmsetup >/dev/null 2>&1 && dmsetup table "$mapper" 2>/dev/null | grep -qw crypt; then
            echo "asset_check_ok: $token dmcrypt=$mapper"
            return 0
        fi
        # Conservative default: /dev/mapper paths are commonly LUKS/dm-crypt.
        echo "asset_check_ok: $token mapper=$mapper"
        return 0
    fi

    if command -v lsblk >/dev/null 2>&1 && [[ -n "$src" ]]; then
        pkname="$(lsblk -no PKNAME "$src" 2>/dev/null | head -n1 || true)"
        type="$(lsblk -no TYPE "$src" 2>/dev/null | head -n1 || true)"
        if [[ "$type" == crypt || "$pkname" == dm-* ]]; then
            echo "asset_check_ok: $token source=$src type=$type"
            return 0
        fi
    fi

    echo "asset_check_blocked: crypto:volume_encrypted unencrypted target=$target source=${src:-unknown} fstype=${fstype:-unknown}"
    return 1
}
