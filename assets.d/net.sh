#!/usr/bin/env bash
# bashqueues standard network asset checks
#
# Installed helper path:
#   ~/.queuebash/assets.d/net.sh
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
