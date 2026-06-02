#!/usr/bin/env bash
# bashqueues reporter plugin: SNMP INFORM
#
# Explicitly disabled unless QUEUEBASH_SNMP_INFORM_DEST and
# QUEUEBASH_SNMP_COMMUNITY are provided by reporting policy/environment.

queue_reporter_facilities() {
    cat <<'FACILITIES'
snmp:inform	Sends configured SNMP INFORM notifications for selected queue events
FACILITIES
}

_queue_reporter_snmp_csv_has() {
    local list="${1:-}" needle="${2:-}" item
    list="${list// /}"
    IFS=',' read -r -a _qb_snmp_items <<< "$list"
    for item in "${_qb_snmp_items[@]}"; do
        [[ "$item" == "$needle" || "$item" == "*" ]] && return 0
    done
    return 1
}

_queue_reporter_snmp_state_int() {
    local event="${1:-}" state="${2:-}" detail="${3:-}"
    case "$state:$event:$detail" in
        pol_blocked:* ) echo 2 ;;
        *:runtime_cap_violation:*|*:log_overflow_kill:* ) echo 3 ;;
        *:failed:*integrity=invalid*|*:failed:*auth*invalid* ) echo 4 ;;
        failed:* ) echo 1 ;;
        * ) echo 0 ;;
    esac
}

queue_reporter_handle_event() {
    local event="$1" job_id="${2:-}" job_name="${3:-}" state="${4:-}" detail="${5:-}" ts="${6:-}"
    local dest community oid version timeout events state_int

    dest="${QUEUEBASH_SNMP_INFORM_DEST:-}"
    community="${QUEUEBASH_SNMP_COMMUNITY:-}"
    oid="${QUEUEBASH_SNMP_TRAP_OID:-.1.3.6.1.4.1.99999.1}"
    version="${QUEUEBASH_SNMP_VERSION:-2c}"
    timeout="${QUEUEBASH_SNMP_TIMEOUT:-5}"
    events="${QUEUEBASH_SNMP_INFORM_EVENTS:-pol_blocked,failed,runtime_cap_violation,log_overflow_kill}"

    [[ -n "$dest" && -n "$community" ]] || return 0
    _queue_reporter_snmp_csv_has "$events" "$event" || _queue_reporter_snmp_csv_has "$events" "$state" || return 0

    if ! command -v snmpinform >/dev/null 2>&1; then
        printf 'reporter_blocked: snmp:inform tool_missing=snmpinform event=%s job_id=%s\n' "$event" "$job_id" >&2
        return 1
    fi

    state_int="$(_queue_reporter_snmp_state_int "$event" "$state" "$detail")"
    [[ "$state_int" =~ ^[0-9]+$ ]] || state_int=0

    timeout "$timeout" snmpinform -v"$version" -c "$community" "$dest" 0 "$oid" \
        "${oid}.1" s "${job_name:-unknown}" \
        "${oid}.2" s "${job_id:-unknown}" \
        "${oid}.3" i "$state_int" \
        "${oid}.4" s "${detail:-$event}" \
        "${oid}.5" s "${ts:-}" >/dev/null 2>&1 || return 1
}
