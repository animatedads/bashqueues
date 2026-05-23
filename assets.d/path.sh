#!/usr/bin/env bash
# bashqueues standard path asset checks
#
# Installed helper path:
#   ~/.queuebash/assets.d/path.sh
#
# Facilities published:
#   path:exists
#   path:mount
#   path:freespace

queue_asset_facilities() {
    cat <<'FACILITIES'
path:exists	Checks that a filesystem path exists
path:mount	Checks that a path is currently a mountpoint
path:freespace	Checks that a directory has at least min_gb/min_mb/min_kb free
FACILITIES
}

queue_asset_param() {
    local key="$1"
    shift
    local p
    for p in "$@"; do
        case "$p" in
            "$key="*) printf '%s\n' "${p#*=}"; return 0 ;;
        esac
    done
    return 1
}

queue_asset_check_path_exists() {
    local token="$1"
    local target="$2"
    shift 2 || true

    if [[ -e "$target" ]]; then
        echo "asset_check_ok: $token"
        return 0
    fi

    echo "asset_check_blocked: path does not exist: $target"
    return 1
}

queue_asset_check_path_mount() {
    local token="$1"
    local target="$2"
    shift 2 || true

    if mountpoint -q -- "$target" 2>/dev/null; then
        echo "asset_check_ok: $token"
        return 0
    fi

    echo "asset_check_blocked: path is not a mountpoint: $target"
    return 1
}

queue_asset_check_path_freespace() {
    local token="$1"
    local target="$2"
    shift 2 || true

    local min_gb min_mb min_kb avail_kb need_kb

    min_gb="$(queue_asset_param min_gb "$@" || true)"
    min_mb="$(queue_asset_param min_mb "$@" || true)"
    min_kb="$(queue_asset_param min_kb "$@" || true)"

    if [[ ! -d "$target" ]]; then
        echo "asset_check_blocked: freespace path is not a directory: $target"
        return 1
    fi

    if [[ -n "$min_gb" ]]; then
        need_kb=$(( min_gb * 1024 * 1024 ))
    elif [[ -n "$min_mb" ]]; then
        need_kb=$(( min_mb * 1024 ))
    elif [[ -n "$min_kb" ]]; then
        need_kb="$min_kb"
    else
        echo "asset_check_blocked: path:freespace requires min_gb=, min_mb=, or min_kb=: $token"
        return 1
    fi

    avail_kb="$(df -Pk -- "$target" 2>/dev/null | awk 'NR==2 {print $4}')"
    if [[ -z "$avail_kb" || ! "$avail_kb" =~ ^[0-9]+$ ]]; then
        echo "asset_check_blocked: unable to read free space for: $target"
        return 1
    fi

    if (( avail_kb < need_kb )); then
        echo "asset_check_blocked: insufficient freespace target=$target available_kb=$avail_kb required_kb=$need_kb"
        return 1
    fi

    echo "asset_check_ok: path:freespace target=$target available_kb=$avail_kb required_kb=$need_kb"
    return 0
}
