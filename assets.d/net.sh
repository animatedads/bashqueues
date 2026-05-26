#!/usr/bin/env bash
# bashqueues standard network asset checks
#
# Installed helper path:
#   ~/.queuebash/assets.d/network.sh
#
# Facilities published:
#   net:http_status
#   net:tcp_endpoint
#   net:interface_state
#   net:interface_bandwidth

queue_asset_facilities() {
    cat <<'FACILITIES'
net:http_status	Checks that an HTTP/HTTPS endpoint returns a 2xx/3xx status code
net:tcp_endpoint	Checks that a TCP endpoint (host:port) is reachable and responding
net:interface_state	Checks that a network interface exists and is in UP state
net:interface_bandwidth	Checks that a network interface has available bandwidth headroom
net:allowance	Checks a charged network interface counter is below an allowance before dispatch
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF'
net:http_status	target=URL	params=timeout=5 accept_status=200,201,204,301,302,304,307,308	example=queue_class_shared_asset net http_status "https://example.com" timeout=5	notes=Blocks dispatch unless the HTTP status is acceptable.
net:tcp_endpoint	target=host:port	params=timeout=5	example=queue_class_shared_asset net tcp_endpoint "db.example.com:5432" timeout=5	notes=Blocks dispatch unless the TCP endpoint is reachable.
net:interface_state	target=interface name	params=none	example=queue_class_shared_asset net interface_state "wwan0"	notes=Blocks dispatch unless the interface exists and is UP.
net:interface_bandwidth	target=interface name	params=max_usage_percent=80 sample_interval=1 max_rate_bytes_per_sec=125000000	example=queue_class_shared_asset net interface_bandwidth "eth0" max_usage_percent=80	notes=Blocks dispatch when sampled link usage exceeds the threshold.
net:allowance	target=interface name	params=allowance_bytes=10G direction=rx_tx counter_file=/path/to/counter	example=queue_class_shared_asset net allowance "wwan0" allowance_bytes=10G direction=rx_tx	notes=Canonical charged-link allowance check. Blocks dispatch when a charged link has already exceeded its allowance.
EOF
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

queue_asset_check_net_http_status() {
    local token="$1"
    local url="$2"
    shift 2 || true

    local timeout accept_status http_code

    timeout="$(queue_asset_param timeout "$@" || echo 5)"
    accept_status="$(queue_asset_param accept_status "$@" || echo '200,201,204,301,302,304,307,308')"

    if [[ -z "$url" ]]; then
        echo "asset_check_blocked: net:http_status requires url parameter"
        return 1
    fi

    # Extract status code, suppress output to /dev/null
    http_code=$(curl -sS -m "$timeout" -o /dev/null -w '%{http_code}' -- "$url" 2>/dev/null || echo "000")

    if [[ ! "$http_code" =~ ^[0-9]{3}$ ]]; then
        echo "asset_check_blocked: net:http_status failed to connect to $url (http_code=$http_code)"
        return 1
    fi

    # Check if status code is in acceptable list (comma-separated)
    if echo ",$accept_status," | grep -q ",$http_code,"; then
        echo "asset_check_ok: net:http_status url=$url http_code=$http_code"
        return 0
    fi

    echo "asset_check_blocked: net:http_status url=$url returned http_code=$http_code (expected: $accept_status)"
    return 1
}

queue_asset_check_net_tcp_endpoint() {
    local token="$1"
    local endpoint="$2"
    shift 2 || true

    local timeout host port

    timeout="$(queue_asset_param timeout "$@" || echo 5)"

    if [[ -z "$endpoint" ]]; then
        echo "asset_check_blocked: net:tcp_endpoint requires endpoint parameter (host:port)"
        return 1
    fi

    # Parse host:port
    host="${endpoint%:*}"
    port="${endpoint##*:}"

    if [[ -z "$host" || -z "$port" || ! "$port" =~ ^[0-9]+$ ]]; then
        echo "asset_check_blocked: net:tcp_endpoint invalid format (expected host:port): $endpoint"
        return 1
    fi

    # Use nc (netcat) with timeout to check connectivity
    if timeout "$timeout" nc -zv "$host" "$port" >/dev/null 2>&1; then
        echo "asset_check_ok: net:tcp_endpoint endpoint=$endpoint"
        return 0
    fi

    echo "asset_check_blocked: net:tcp_endpoint cannot reach $endpoint (timeout=${timeout}s)"
    return 1
}

queue_asset_check_net_interface_state() {
    local token="$1"
    local interface="$2"
    shift 2 || true

    if [[ -z "$interface" ]]; then
        echo "asset_check_blocked: net:interface_state requires interface parameter"
        return 1
    fi

    # Check if interface exists
    if [[ ! -d "/sys/class/net/$interface" ]]; then
        echo "asset_check_blocked: net:interface_state interface does not exist: $interface"
        return 1
    fi

    # Check if interface is UP
    local operstate
    operstate=$(cat "/sys/class/net/$interface/operstate" 2>/dev/null)

    if [[ "$operstate" == "up" ]]; then
        echo "asset_check_ok: net:interface_state interface=$interface operstate=$operstate"
        return 0
    fi

    echo "asset_check_blocked: net:interface_state interface=$interface is not UP (operstate=$operstate)"
    return 1
}

queue_asset_check_net_interface_bandwidth() {
    local token="$1"
    local interface="$2"
    shift 2 || true

    local max_usage_percent rx_bytes_before tx_bytes_before rx_bytes_after tx_bytes_after
    local rx_rate tx_rate total_rate max_rate sample_interval

    if [[ -z "$interface" ]]; then
        echo "asset_check_blocked: net:interface_bandwidth requires interface parameter"
        return 1
    fi

    max_usage_percent="$(queue_asset_param max_usage_percent "$@" || echo 80)"
    sample_interval="$(queue_asset_param sample_interval "$@" || echo 2)"

    # Check if interface exists
    if [[ ! -d "/sys/class/net/$interface" ]]; then
        echo "asset_check_blocked: net:interface_bandwidth interface does not exist: $interface"
        return 1
    fi

    # Get initial byte counts
    rx_bytes_before=$(cat "/sys/class/net/$interface/statistics/rx_bytes" 2>/dev/null)
    tx_bytes_before=$(cat "/sys/class/net/$interface/statistics/tx_bytes" 2>/dev/null)

    if [[ -z "$rx_bytes_before" || -z "$tx_bytes_before" ]]; then
        echo "asset_check_blocked: net:interface_bandwidth unable to read statistics for: $interface"
        return 1
    fi

    # Sleep for sample interval
    sleep "$sample_interval"

    # Get final byte counts
    rx_bytes_after=$(cat "/sys/class/net/$interface/statistics/rx_bytes" 2>/dev/null)
    tx_bytes_after=$(cat "/sys/class/net/$interface/statistics/tx_bytes" 2>/dev/null)

    if [[ -z "$rx_bytes_after" || -z "$tx_bytes_after" ]]; then
        echo "asset_check_blocked: net:interface_bandwidth unable to read statistics for: $interface"
        return 1
    fi

    # Calculate rates (bytes per second)
    rx_rate=$(( (rx_bytes_after - rx_bytes_before) / sample_interval ))
    tx_rate=$(( (tx_bytes_after - tx_bytes_before) / sample_interval ))
    total_rate=$(( rx_rate + tx_rate ))

    # Estimate max rate: Assume 1Gbps interface as baseline (125MB/s), scale by max_usage_percent
    # For 1Gbps: 1000000000 bps = 125000000 bytes/s
    # Adjust based on observed interface speed if available
    max_rate=$(( 125000000 * max_usage_percent / 100 ))

    if (( total_rate < max_rate )); then
        echo "asset_check_ok: net:interface_bandwidth interface=$interface rx_rate_mbps=$(( rx_rate * 8 / 1000000 )) tx_rate_mbps=$(( tx_rate * 8 / 1000000 )) total_rate_mbps=$(( total_rate * 8 / 1000000 )) max_allowed_mbps=$(( max_rate * 8 / 1000000 ))"
        return 0
    fi

    echo "asset_check_blocked: net:interface_bandwidth interface=$interface total_rate_mbps=$(( total_rate * 8 / 1000000 )) exceeds max_allowed_mbps=$(( max_rate * 8 / 1000000 )) at max_usage_percent=$max_usage_percent"
    return 1
}

queue_asset_hints() {
    cat <<'EOF'
net:http_status	target=URL or host, e.g. https://github.com	params=timeout=5 accept_status=200,201,204,301,302,304,307,308,403	example=queue_class_shared_asset net http_status "https://github.com" timeout=5 accept_status=200,301,302	notes=Checks that HTTP/HTTPS endpoint returns an accepted status code.
net:tcp_endpoint	target=host:port, e.g. db.internal:5432	params=timeout=3	example=queue_class_shared_asset net tcp_endpoint "db.internal:5432" timeout=3	notes=Checks TCP connect reachability.
net:interface_state	target=interface name, e.g. tun0	params=state=UP	example=queue_class_shared_asset net interface_state "tun0" state=UP	notes=Checks that a network interface exists and is in the requested state.
net:interface_bandwidth	target=interface name, e.g. eth0	params=min_mbps=10	example=queue_class_shared_asset net interface_bandwidth "eth0" min_mbps=10	notes=Checks network interface bandwidth headroom where supported.
EOF
}


_queue_asset_net_allowance_parse_bytes() {
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

_queue_asset_net_allowance_counter() {
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

queue_asset_check_net_allowance() {
    local iface="${1:-}"
    shift || true

    local allowance direction counter_file used allowance_b
    allowance="$(queue_asset_param allowance_bytes "$@" || true)"
    direction="$(queue_asset_param direction "$@" || echo rx_tx)"
    counter_file="$(queue_asset_param counter_file "$@" || true)"

    [[ -n "$iface" ]] || { echo "asset_check_blocked: net:allowance interface_required"; return 1; }
    [[ -n "$allowance" ]] || { echo "asset_check_blocked: net:allowance allowance_bytes_required iface=$iface"; return 1; }

    allowance_b="$(_queue_asset_net_allowance_parse_bytes "$allowance" 2>/dev/null || echo "$allowance")"
    [[ "$allowance_b" =~ ^[0-9]+$ ]] || { echo "asset_check_blocked: net:allowance invalid_allowance=$allowance"; return 1; }

    used="$(_queue_asset_net_allowance_counter "$iface" "$direction" "$counter_file" 2>/dev/null || true)"
    [[ "$used" =~ ^[0-9]+$ ]] || { echo "asset_check_blocked: net:allowance cannot_read_counter iface=$iface"; return 1; }

    if (( used > allowance_b )); then
        echo "asset_check_blocked: net:allowance exceeded iface=$iface used_bytes=$used allowance_bytes=$allowance_b direction=$direction"
        return 1
    fi

    echo "asset_check_ok: net:allowance iface=$iface used_bytes=$used allowance_bytes=$allowance_b direction=$direction"
}
