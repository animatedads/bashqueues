#!/usr/bin/env bash
# Deprecated compatibility helper for the old net_usage:allowance facility.
#
# Canonical facility:
#   net:allowance
#
# Compatibility facility retained for existing class files:
#   net_usage:allowance

queue_asset_facilities() {
    cat <<'EOF_FACILITIES'
net_usage:allowance Deprecated compatibility alias for net:allowance; checks a charged network interface counter is below an allowance before dispatch
EOF_FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
net_usage:allowance	target=interface name	params=allowance_bytes=10G direction=rx_tx counter_file=/path/to/counter	example=queue_class_shared_asset net_usage allowance "wwan0" allowance_bytes=10G direction=rx_tx	notes=Deprecated compatibility alias. Prefer: queue_class_shared_asset net allowance "wwan0" allowance_bytes=10G direction=rx_tx
EOF_HINTS
}

_queue_asset_net_usage_param() {
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

_queue_asset_net_usage_parse_bytes() {
    local v="${1:-}" n unit
    if [[ "$v" =~ ^([0-9]+)([KkMmGgTt]?[Bb]?)?$ ]]; then
        n="${BASH_REMATCH[1]}"
        unit="${BASH_REMATCH[2]}"
        case "$unit" in
            ""|B|b) echo "$n" ;;
            K|k|KB|kb|Kb|kB) echo $((n * 1024)) ;;
            M|m|MB|mb|Mb|mB) echo $((n * 1024 * 1024)) ;;
            G|g|GB|gb|Gb|gB) echo $((n * 1024 * 1024 * 1024)) ;;
            T|t|TB|tb|Tb|tB) echo $((n * 1024 * 1024 * 1024 * 1024)) ;;
            *) return 1 ;;
        esac
    else
        return 1
    fi
}

_queue_asset_net_usage_counter() {
    local iface="$1" dir="${2:-rx_tx}" counter_file="${3:-}"
    local base="/sys/class/net/$iface/statistics" rx tx

    if [[ -n "$counter_file" ]]; then
        cat "$counter_file" 2>/dev/null
        return
    fi

    [[ -n "$iface" && -d "$base" ]] || return 1

    rx="$(cat "$base/rx_bytes" 2>/dev/null || echo 0)"
    tx="$(cat "$base/tx_bytes" 2>/dev/null || echo 0)"
    [[ "$rx" =~ ^[0-9]+$ ]] || rx=0
    [[ "$tx" =~ ^[0-9]+$ ]] || tx=0

    case "$dir" in
        rx) echo "$rx" ;;
        tx) echo "$tx" ;;
        rx_tx|total|*) echo $((rx + tx)) ;;
    esac
}

queue_asset_check_net_usage_allowance() {
    local iface="${1:-}"
    shift || true

    local allowance direction counter_file used allowance_b
    allowance="$(_queue_asset_net_usage_param allowance_bytes "$@" || true)"
    direction="$(_queue_asset_net_usage_param direction "$@" || echo rx_tx)"
    counter_file="$(_queue_asset_net_usage_param counter_file "$@" || true)"

    [[ -n "$iface" ]] || { echo "asset_check_blocked: net_usage:allowance interface_required"; return 1; }
    [[ -n "$allowance" ]] || { echo "asset_check_blocked: net_usage:allowance allowance_bytes_required iface=$iface"; return 1; }

    allowance_b="$(_queue_asset_net_usage_parse_bytes "$allowance" 2>/dev/null || echo "$allowance")"
    [[ "$allowance_b" =~ ^[0-9]+$ ]] || { echo "asset_check_blocked: net_usage:allowance invalid_allowance=$allowance"; return 1; }

    used="$(_queue_asset_net_usage_counter "$iface" "$direction" "$counter_file" 2>/dev/null || true)"
    [[ "$used" =~ ^[0-9]+$ ]] || { echo "asset_check_blocked: net_usage:allowance cannot_read_counter iface=$iface"; return 1; }

    if (( used > allowance_b )); then
        echo "asset_check_blocked: net_usage:allowance exceeded iface=$iface used_bytes=$used allowance_bytes=$allowance_b direction=$direction"
        return 1
    fi

    echo "asset_check_ok: net_usage:allowance iface=$iface used_bytes=$used allowance_bytes=$allowance_b direction=$direction"
}
