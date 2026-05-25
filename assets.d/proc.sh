#!/usr/bin/env bash
# bashqueues process asset checks
#
# Facilities published:
#   proc:running
#   proc:not_running
#   proc:user_running
#   proc:pid_file
#   proc:max_instances
#   proc:cpu_user
#   proc:mem_user

queue_asset_facilities() {
    cat <<'FACILITIES'
proc:cpu_user	Check a named process is using less than N percent CPU
proc:max_instances	Check fewer than N instances of a named process are running
proc:mem_user	Check a named process is using less than N MB RSS
proc:not_running	Check a named process is not currently running
proc:pid_file	Check a PID file exists and the recorded PID is alive
proc:running	Check a named process is currently running
proc:user_running	Check a process owned by a specific user is running
FACILITIES
}

queue_asset_hints() {
    cat <<'HINTS'
proc:running	target=process name or command pattern	params=match=exact|substr|regex user=<unix user>	example=queue_class_shared_asset proc running "gpsd" match=exact	notes=Blocks dispatch unless at least one matching process exists. Use match=exact for process name or match=substr for command-line substring.
proc:not_running	target=process name or command pattern	params=match=exact|substr|regex user=<unix user>	example=queue_class_shared_asset proc not_running "nightly_export.sh" match=substr	notes=Anti-prerequisite pattern. Passes when no matching process exists, useful to prevent duplicate launches.
proc:user_running	target=process name or command pattern	params=user=<unix user> match=exact|substr|regex	example=queue_class_shared_asset proc user_running "postgres" user=postgres	notes=Blocks unless a matching process owned by the requested Unix user exists.
proc:pid_file	target=path to PID file	params=stale_ok=0	example=queue_class_shared_asset proc pid_file "/run/mydaemon.pid" stale_ok=0	notes=Reads the PID from the file and checks /proc/<pid>. stale_ok=1 treats missing/dead PID as pass.
proc:max_instances	target=process name or command pattern	params=max=1 match=exact|substr|regex user=<unix user>	example=queue_class_shared_asset proc max_instances "enhance" max=1 match=exact	notes=Passes when the matching process count is less than or equal to max.
proc:cpu_user	target=process name or command pattern	params=max_cpu_pct=80 match=exact|substr|regex user=<unix user>	example=queue_class_shared_asset proc cpu_user "ffmpeg" max_cpu_pct=350 match=substr	notes=Uses ps when available; CPU percentage may exceed 100 on multicore systems.
proc:mem_user	target=process name or command pattern	params=max_rss_mb=500 match=exact|substr|regex user=<unix user>	example=queue_class_shared_asset proc mem_user "python" max_rss_mb=2048 match=substr	notes=Uses /proc status RSS values where possible and falls back to ps.
HINTS
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

_queue_asset_proc_pids() {
    local pattern="$1"
    shift || true
    local match user pid comm cmd owner
    match="$(queue_asset_param match "$@" || echo exact)"
    user="$(queue_asset_param user "$@" || true)"

    if command -v pgrep >/dev/null 2>&1; then
        local args=()
        case "$match" in
            exact) args=(-x "$pattern") ;;
            substr|regex) args=(-f "$pattern") ;;
            *) args=(-x "$pattern") ;;
        esac
        if [[ -n "$user" ]]; then
            pgrep -u "$user" "${args[@]}" 2>/dev/null || true
        else
            pgrep "${args[@]}" 2>/dev/null || true
        fi
        return 0
    fi

    for d in /proc/[0-9]*; do
        [[ -r "$d/status" ]] || continue
        pid="${d##*/}"
        comm="$(awk '/^Name:/ {print $2; exit}' "$d/status" 2>/dev/null)"
        cmd="$(tr '\0' ' ' < "$d/cmdline" 2>/dev/null)"
        owner="$(stat -c %U "$d" 2>/dev/null || true)"
        [[ -n "$user" && "$owner" != "$user" ]] && continue
        case "$match" in
            exact) [[ "$comm" == "$pattern" ]] && echo "$pid" ;;
            substr) [[ "$cmd" == *"$pattern"* || "$comm" == *"$pattern"* ]] && echo "$pid" ;;
            regex) [[ "$cmd" =~ $pattern || "$comm" =~ $pattern ]] && echo "$pid" ;;
            *) [[ "$comm" == "$pattern" ]] && echo "$pid" ;;
        esac
    done
}

_queue_asset_proc_count() {
    local pattern="$1"
    shift || true
    _queue_asset_proc_pids "$pattern" "$@" | awk 'NF {n++} END {print n+0}'
}

queue_asset_check_proc_running() {
    local target="$1"; shift || true
    local count
    count="$(_queue_asset_proc_count "$target" "$@")"
    if (( count > 0 )); then
        echo "asset_check_ok: proc:running target=$target count=$count"
        return 0
    fi
    echo "asset_check_blocked: proc:running target=$target count=0"
    return 1
}

queue_asset_check_proc_not_running() {
    local target="$1"; shift || true
    local count
    count="$(_queue_asset_proc_count "$target" "$@")"
    if (( count == 0 )); then
        echo "asset_check_ok: proc:not_running target=$target count=0"
        return 0
    fi
    echo "asset_check_blocked: proc:not_running target=$target count=$count"
    return 1
}

queue_asset_check_proc_user_running() {
    local target="$1"; shift || true
    local user count
    user="$(queue_asset_param user "$@" || true)"
    if [[ -z "$user" ]]; then
        echo "asset_check_blocked: proc:user_running target=$target requires user=<unix user>"
        return 1
    fi
    count="$(_queue_asset_proc_count "$target" "$@")"
    if (( count > 0 )); then
        echo "asset_check_ok: proc:user_running target=$target user=$user count=$count"
        return 0
    fi
    echo "asset_check_blocked: proc:user_running target=$target user=$user count=0"
    return 1
}

queue_asset_check_proc_pid_file() {
    local target="$1"; shift || true
    local stale_ok pid
    stale_ok="$(queue_asset_param stale_ok "$@" || echo 0)"
    if [[ ! -f "$target" ]]; then
        if [[ "$stale_ok" == "1" ]]; then
            echo "asset_check_ok: proc:pid_file target=$target missing stale_ok=1"
            return 0
        fi
        echo "asset_check_blocked: proc:pid_file target=$target missing=1"
        return 1
    fi
    read -r pid < "$target" || true
    pid="${pid%%[^0-9]*}"
    if [[ -n "$pid" && -d "/proc/$pid" ]]; then
        echo "asset_check_ok: proc:pid_file target=$target pid=$pid alive=1"
        return 0
    fi
    if [[ "$stale_ok" == "1" ]]; then
        echo "asset_check_ok: proc:pid_file target=$target stale=1 stale_ok=1"
        return 0
    fi
    echo "asset_check_blocked: proc:pid_file target=$target pid=${pid:-unknown} alive=0"
    return 1
}

queue_asset_check_proc_max_instances() {
    local target="$1"; shift || true
    local max count
    max="$(queue_asset_param max "$@" || echo 1)"
    if [[ ! "$max" =~ ^[0-9]+$ ]]; then
        echo "asset_check_blocked: proc:max_instances target=$target invalid max=$max"
        return 1
    fi
    count="$(_queue_asset_proc_count "$target" "$@")"
    if (( count <= max )); then
        echo "asset_check_ok: proc:max_instances target=$target count=$count max=$max"
        return 0
    fi
    echo "asset_check_blocked: proc:max_instances target=$target count=$count max=$max"
    return 1
}

_queue_asset_proc_max_cpu() {
    local max=0 pid value
    for pid in "$@"; do
        value="$(ps -p "$pid" -o %cpu= 2>/dev/null | awk '{print int($1+0)}')"
        [[ "$value" =~ ^[0-9]+$ ]] || value=0
        (( value > max )) && max="$value"
    done
    echo "$max"
}

_queue_asset_proc_max_rss_mb() {
    local max=0 pid kb value
    for pid in "$@"; do
        kb="$(awk '/^VmRSS:/ {print $2; exit}' "/proc/$pid/status" 2>/dev/null)"
        if [[ ! "$kb" =~ ^[0-9]+$ ]]; then
            kb="$(ps -p "$pid" -o rss= 2>/dev/null | awk '{print int($1+0)}')"
        fi
        [[ "$kb" =~ ^[0-9]+$ ]] || kb=0
        value=$(( (kb + 1023) / 1024 ))
        (( value > max )) && max="$value"
    done
    echo "$max"
}

queue_asset_check_proc_cpu_user() {
    local target="$1"; shift || true
    local max_cpu pids value
    max_cpu="$(queue_asset_param max_cpu_pct "$@" || echo 80)"
    pids=( $(_queue_asset_proc_pids "$target" "$@") )
    if (( ${#pids[@]} == 0 )); then
        echo "asset_check_ok: proc:cpu_user target=$target count=0"
        return 0
    fi
    value="$(_queue_asset_proc_max_cpu "${pids[@]}")"
    if awk "BEGIN {exit !($value <= $max_cpu)}"; then
        echo "asset_check_ok: proc:cpu_user target=$target max_cpu_pct_seen=$value limit=$max_cpu count=${#pids[@]}"
        return 0
    fi
    echo "asset_check_blocked: proc:cpu_user target=$target max_cpu_pct_seen=$value limit=$max_cpu count=${#pids[@]}"
    return 1
}

queue_asset_check_proc_mem_user() {
    local target="$1"; shift || true
    local max_mb pids value
    max_mb="$(queue_asset_param max_rss_mb "$@" || echo 500)"
    pids=( $(_queue_asset_proc_pids "$target" "$@") )
    if (( ${#pids[@]} == 0 )); then
        echo "asset_check_ok: proc:mem_user target=$target count=0"
        return 0
    fi
    value="$(_queue_asset_proc_max_rss_mb "${pids[@]}")"
    if (( value <= max_mb )); then
        echo "asset_check_ok: proc:mem_user target=$target max_rss_mb_seen=$value limit=$max_mb count=${#pids[@]}"
        return 0
    fi
    echo "asset_check_blocked: proc:mem_user target=$target max_rss_mb_seen=$value limit=$max_mb count=${#pids[@]}"
    return 1
}
