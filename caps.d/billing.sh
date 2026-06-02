#!/usr/bin/env bash
queue_cap_facilities() {
    echo "billing:cycle_timeout Derives a timeout from billable unit/cycle/grace class defaults"
}
queue_cap_candidate_billing_cycle_timeout() {
    local unit="${BILLING_UNIT_SECONDS:-}" cycles="${BILLING_CYCLES:-}" grace="${BILLING_GRACE_SECONDS:-0}" unit_s grace_s total
    [[ -n "$unit" && -n "$cycles" ]] || return 0
    [[ "$cycles" =~ ^[0-9]+$ ]] || return 0
    unit_s="$(_queue_duration_to_seconds "$unit" 2>/dev/null || true)"
    [[ "$unit_s" =~ ^[0-9]+$ ]] || return 0
    grace_s="$(_queue_duration_to_seconds "$grace" 2>/dev/null || true)"
    [[ "$grace_s" =~ ^[0-9]+$ ]] || grace_s=0
    total=$((unit_s * cycles - grace_s)); (( total < 1 )) && total=1
    printf 'timeout\t%s\tbilling:cycle_timeout\tunit=%s cycles=%s grace=%s\n' "$total" "$unit" "$cycles" "$grace"
}
