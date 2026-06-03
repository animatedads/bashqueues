#!/usr/bin/env bash
# bashqueues reporter plugin: Prometheus textfile collector

queue_reporter_facilities() {
    cat <<'FACILITIES'
prom:textfile	Writes selected queue event counters to a Prometheus node-exporter textfile directory
FACILITIES
}

_queue_reporter_prom_csv_has() {
    local list="${1:-}" needle="${2:-}" item
    list="${list// /}"
    IFS=',' read -r -a _qb_prom_items <<< "$list"
    for item in "${_qb_prom_items[@]}"; do
        [[ "$item" == "$needle" || "$item" == "*" ]] && return 0
    done
    return 1
}

_queue_reporter_prom_label() {
    local s="${1:-unknown}"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/ }"
    printf '%s' "$s"
}

queue_reporter_handle_event() {
    local event="${1:-}" job_id="${2:-}" job_name="${3:-}" state="${4:-}" detail="${5:-}" ts="${6:-}"
    local dir file tmp events

    dir="${QUEUEBASH_PROM_DIR:-}"
    events="${QUEUEBASH_PROM_EVENTS:-failed,pol_blocked,runtime_cap_violation,log_overflow_kill}"
    [[ -n "$dir" && -d "$dir" ]] || return 0
    _queue_reporter_prom_csv_has "$events" "$event" || _queue_reporter_prom_csv_has "$events" "$state" || return 0

    file="$dir/bashqueues_events.prom"
    tmp="$dir/bashqueues_events.prom.$$"
    {
        printf '# HELP bashqueues_event_last_info Last observed bashqueues event.\n'
        printf '# TYPE bashqueues_event_last_info gauge\n'
        printf 'bashqueues_event_last_info{event="%s",state="%s",job_id="%s",job_name="%s",detail="%s",ts="%s"} 1\n' \
            "$(_queue_reporter_prom_label "$event")" \
            "$(_queue_reporter_prom_label "$state")" \
            "$(_queue_reporter_prom_label "$job_id")" \
            "$(_queue_reporter_prom_label "$job_name")" \
            "$(_queue_reporter_prom_label "$detail")" \
            "$(_queue_reporter_prom_label "$ts")"
    } > "$tmp" || return 1
    mv -- "$tmp" "$file" 2>/dev/null || { rm -f -- "$tmp"; return 1; }
}
