#!/usr/bin/env bash
# bashqueues standard system asset checks
#
# Installed helper path:
#   ~/.queuebash/assets.d/system.sh
#
# Facilities published:
#   sys:memory_available
#   sys:cpu_load
#   sys:cpu_cores
#   sys:iowait
#   sys:process_count

queue_asset_facilities() {
    cat <<'FACILITIES'
sys:memory_available	Checks that system has minimum available RAM
sys:cpu_load	Checks that system load average is below threshold
sys:cpu_cores	Checks that minimum idle CPU cores are available
sys:iowait	Checks that I/O wait percentage is below threshold
sys:process_count	Checks that current process count is below threshold
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

queue_asset_check_sys_memory_available() {
    local token="$1"
    local positional_min_gb="${2:-}"
    shift 2 || true

    local min_gb="" min_mb="" required_mb="" required_label=""
    local available_kb available_mb available_gb

    min_gb="$(queue_asset_param min_gb "$@" || true)"
    min_mb="$(queue_asset_param min_mb "$@" || true)"

    # Backward compatibility: the second positional argument was historically
    # interpreted as a GiB threshold.  Named parameters are preferred.
    if [[ -z "$min_gb" && -z "$min_mb" && -n "$positional_min_gb" ]]; then
        min_gb="$positional_min_gb"
    fi

    if [[ -n "$min_mb" ]]; then
        if [[ ! "$min_mb" =~ ^[0-9]+$ ]]; then
            echo "asset_check_blocked: sys:memory_available requires min_mb parameter (numeric)"
            return 1
        fi
        required_mb="$min_mb"
        required_label="required_mb=$min_mb"
    elif [[ -n "$min_gb" ]]; then
        if [[ ! "$min_gb" =~ ^[0-9]+$ ]]; then
            echo "asset_check_blocked: sys:memory_available requires min_gb parameter (numeric)"
            return 1
        fi
        required_mb=$(( min_gb * 1024 ))
        required_label="required_gb=$min_gb"
    else
        echo "asset_check_blocked: sys:memory_available requires min_gb or min_mb parameter (numeric)"
        return 1
    fi

    # Read from /proc/meminfo, MemAvailable accounts for reclaimable caches.
    available_kb=$(awk '/MemAvailable/ {print $2}' /proc/meminfo 2>/dev/null)

    if [[ -z "$available_kb" || ! "$available_kb" =~ ^[0-9]+$ ]]; then
        echo "asset_check_blocked: sys:memory_available unable to read /proc/meminfo"
        return 1
    fi

    available_mb=$(( available_kb / 1024 ))
    available_gb=$(( available_mb / 1024 ))

    if (( available_mb >= required_mb )); then
        echo "asset_check_ok: sys:memory_available available_mb=$available_mb available_gb=$available_gb $required_label"
        return 0
    fi

    echo "asset_check_blocked: sys:memory_available available_mb=$available_mb available_gb=$available_gb below $required_label"
    return 1
}

queue_asset_check_sys_cpu_load() {
    local token="$1"
    local max_load_1m="$2"
    shift 2 || true

    local load_1m load_5m load_15m

    max_load_1m="$(queue_asset_param max_load_1m "$@" || echo "$max_load_1m")"

    if [[ -z "$max_load_1m" ]]; then
        echo "asset_check_blocked: sys:cpu_load requires max_load_1m parameter (e.g., 4.0)"
        return 1
    fi

    # Read from /proc/loadavg
    read -r load_1m load_5m load_15m < /proc/loadavg

    if [[ -z "$load_1m" ]]; then
        echo "asset_check_blocked: sys:cpu_load unable to read /proc/loadavg"
        return 1
    fi

    # Floating-point comparison using awk
    if awk "BEGIN {exit !($load_1m < $max_load_1m)}"; then
        echo "asset_check_ok: sys:cpu_load load_1m=$load_1m load_5m=$load_5m load_15m=$load_15m max_load_1m=$max_load_1m"
        return 0
    fi

    echo "asset_check_blocked: sys:cpu_load load_1m=$load_1m exceeds max_load_1m=$max_load_1m"
    return 1
}

queue_asset_check_sys_cpu_cores() {
    local token="$1"
    local min_idle="$2"
    shift 2 || true

    local nproc load_1m idle_cores

    min_idle="$(queue_asset_param min_idle "$@" || echo "$min_idle")"

    if [[ -z "$min_idle" || ! "$min_idle" =~ ^[0-9]+$ ]]; then
        echo "asset_check_blocked: sys:cpu_cores requires min_idle parameter (numeric cores)"
        return 1
    fi

    # Get total cores
    nproc=$(nproc 2>/dev/null)
    if [[ -z "$nproc" || ! "$nproc" =~ ^[0-9]+$ ]]; then
        echo "asset_check_blocked: sys:cpu_cores unable to determine CPU count"
        return 1
    fi

    # Read 1-minute load average
    read -r load_1m < /proc/loadavg
    if [[ -z "$load_1m" ]]; then
        echo "asset_check_blocked: sys:cpu_cores unable to read /proc/loadavg"
        return 1
    fi

    # Estimate idle cores: cores - load_1m (accounting for floating load)
    # Using bash arithmetic (truncates to integer), so we use awk
    idle_cores=$(awk "BEGIN {cores=$nproc; load=$load_1m; idle=int(cores - load); print (idle < 0 ? 0 : idle)}")

    if (( idle_cores >= min_idle )); then
        echo "asset_check_ok: sys:cpu_cores idle_cores=$idle_cores total_cores=$nproc load_1m=$load_1m required_idle=$min_idle"
        return 0
    fi

    echo "asset_check_blocked: sys:cpu_cores idle_cores=$idle_cores below required_idle=$min_idle"
    return 1
}

queue_asset_check_sys_iowait() {
    local token="$1"
    local max_iowait_pct="$2"
    shift 2 || true

    local iowait_pct sample_interval

    max_iowait_pct="$(queue_asset_param max_iowait_pct "$@" || echo "$max_iowait_pct")"
    sample_interval="$(queue_asset_param sample_interval "$@" || echo 1)"

    if [[ -z "$max_iowait_pct" || ! "$max_iowait_pct" =~ ^[0-9]+$ ]]; then
        echo "asset_check_blocked: sys:iowait requires max_iowait_pct parameter (0-100)"
        return 1
    fi

    # Use vmstat to get I/O wait percentage
    # vmstat outputs: CPU %user %nice %system %idle %wait %hardware %software %steal
    # We want the %wait column (position depends on vmstat version, typically 5th data field)
    iowait_pct=$(vmstat 1 2 2>/dev/null | tail -1 | awk '{print $16}')

    if [[ -z "$iowait_pct" || ! "$iowait_pct" =~ ^[0-9]+$ ]]; then
        echo "asset_check_blocked: sys:iowait unable to parse vmstat output"
        return 1
    fi

    if (( iowait_pct <= max_iowait_pct )); then
        echo "asset_check_ok: sys:iowait iowait_pct=$iowait_pct max_iowait_pct=$max_iowait_pct"
        return 0
    fi

    echo "asset_check_blocked: sys:iowait iowait_pct=$iowait_pct exceeds max_iowait_pct=$max_iowait_pct"
    return 1
}

queue_asset_check_sys_process_count() {
    local token="$1"
    local max_processes="$2"
    shift 2 || true

    local current_process_count

    max_processes="$(queue_asset_param max_processes "$@" || echo "$max_processes")"

    if [[ -z "$max_processes" || ! "$max_processes" =~ ^[0-9]+$ ]]; then
        echo "asset_check_blocked: sys:process_count requires max_processes parameter (numeric)"
        return 1
    fi

    # Count total processes from /proc
    current_process_count=$(ls -d /proc/[0-9]* 2>/dev/null | wc -l)

    if [[ -z "$current_process_count" || ! "$current_process_count" =~ ^[0-9]+$ ]]; then
        echo "asset_check_blocked: sys:process_count unable to count processes"
        return 1
    fi

    if (( current_process_count <= max_processes )); then
        echo "asset_check_ok: sys:process_count current_process_count=$current_process_count max_processes=$max_processes"
        return 0
    fi

    echo "asset_check_blocked: sys:process_count current_process_count=$current_process_count exceeds max_processes=$max_processes"
    return 1
}

queue_asset_hints() {
    cat <<'EOF'
sys:cpu_load	target=system	params=max_load=4.0	example=queue_class_shared_asset sys cpu_load "system" max_load=4.0	notes=Checks system load average.
sys:memory_available	target=system	params=min_gb=8 min_mb=512	example=queue_class_shared_asset sys memory_available "system" min_gb=8	notes=Checks available memory.
sys:cpu_cores	target=system	params=min_idle=2	example=queue_class_shared_asset sys cpu_cores "system" min_idle=2	notes=Checks idle CPU core availability.
sys:iowait	target=system	params=max_percent=10	example=queue_class_shared_asset sys iowait "system" max_percent=10	notes=Checks I/O wait percentage.
sys:process_count	target=system	params=max_processes=1000	example=queue_class_shared_asset sys process_count "system" max_processes=1000	notes=Checks current process count threshold.
EOF
}
