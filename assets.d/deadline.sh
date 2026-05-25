#!/usr/bin/env bash
# bashqueues standard deadline asset checks
#
# Facilities published:
#   deadline:monitor  Deterministically calculates slack and boosts priority as a deadline approaches.
#   deadline:panic    Calculates slack; after the point of no return it can apply class-declared fallback asset exceptions.
#
# This helper is deliberately computational only.  No AI/LLM decisions are made.
# Expected duration is the median of historical completed jobs with the same JOB_NAME,
# optionally filtered for month-end style workloads.

queue_asset_facilities() {
    cat <<'FACILITIES'
deadline:monitor	Calculates deterministic deadline slack and raises job priority as the point of no return approaches
deadline:panic	Calculates deterministic deadline slack and, after the point of no return, applies class-declared fallback asset exceptions
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
deadline:monitor	target=deadline policy name	params=drop_dead=05:00 margin_pct=15 pattern=standard|month-end warn_slack=3600 warn_priority=50 critical_priority=99 start_worker=0 start_worker_slack=0 max_extra_workers=1 min_samples=1 fallback_duration=180m now_epoch=TEST	example=CLASS_DEADLINE_ALLOW_EXTRA_WORKER=1; queue_class_shared_asset deadline monitor nightly-recon drop_dead=05:00 margin_pct=15 pattern=month-end start_worker=1	notes=Always allows dispatch to continue, but mutates pending job priority based on deterministic slack calculation. Can start a bounded extra detached worker after escalation when enabled by class/parameter.
deadline:panic	target=deadline policy name	params=drop_dead=05:00 margin_pct=15 pattern=standard|month-end critical_priority=99 start_worker=0 start_worker_slack=0 max_extra_workers=1 min_samples=1 fallback_duration=180m panic_assets="snmp time:window" now_epoch=TEST	example=CLASS_DEADLINE_FALLBACK_ASSETS="snmp time:window"; CLASS_DEADLINE_ALLOW_EXTRA_WORKER=1; queue_class_shared_asset deadline panic nightly-recon drop_dead=05:00 pattern=month-end start_worker=1	notes=When slack is zero/negative, applies only class-declared fallback asset exceptions so later assets in the class can be bypassed without changing policy/signature material. Can start a bounded extra detached worker after escalation when enabled.
EOF_HINTS
}

_queue_deadline_param() {
    local key="$1" p
    shift || true
    for p in "$@"; do
        case "$p" in
            "$key="*) printf '%s\n' "${p#*=}"; return 0 ;;
        esac
    done
    return 1
}

_queue_deadline_now_epoch() {
    local v
    v="$(_queue_deadline_param now_epoch "$@" || true)"
    if [[ -n "$v" ]]; then
        [[ "$v" =~ ^[0-9]+$ ]] || { echo "asset_check_blocked: deadline invalid now_epoch=$v"; return 1; }
        printf '%s\n' "$v"
    else
        date +%s
    fi
}

_queue_deadline_duration_seconds() {
    local raw="${1:-}" n unit
    [[ -n "$raw" ]] || return 1
    if [[ "$raw" =~ ^([0-9]+)(s|sec|secs|second|seconds)?$ ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"; return 0
    fi
    if [[ "$raw" =~ ^([0-9]+)(m|min|mins|minute|minutes)$ ]]; then
        n="${BASH_REMATCH[1]}"; printf '%s\n' "$((10#$n * 60))"; return 0
    fi
    if [[ "$raw" =~ ^([0-9]+)(h|hr|hrs|hour|hours)$ ]]; then
        n="${BASH_REMATCH[1]}"; printf '%s\n' "$((10#$n * 3600))"; return 0
    fi
    return 1
}

_queue_deadline_drop_dead_epoch() {
    local drop_dead="${1:-}" now="${2:-}" today epoch
    [[ -n "$drop_dead" ]] || { echo "asset_check_blocked: deadline requires drop_dead=HH:MM|ISO|epoch"; return 1; }
    if [[ "$drop_dead" =~ ^[0-9]+$ ]]; then
        printf '%s\n' "$drop_dead"; return 0
    fi
    if [[ "$drop_dead" =~ ^([0-9]{1,2}):([0-9]{2})$ ]]; then
        today="$(date -d "@$now" +%F 2>/dev/null || date +%F)"
        epoch="$(date -d "$today $drop_dead" +%s 2>/dev/null || true)"
        [[ -n "$epoch" ]] || { echo "asset_check_blocked: deadline cannot parse drop_dead=$drop_dead"; return 1; }
        # If the clock time has already passed today, treat it as tomorrow's deadline.
        if (( epoch <= now )); then
            epoch="$(date -d "$today $drop_dead +1 day" +%s 2>/dev/null || true)"
        fi
        printf '%s\n' "$epoch"; return 0
    fi
    epoch="$(date -d "$drop_dead" +%s 2>/dev/null || true)"
    [[ -n "$epoch" ]] || { echo "asset_check_blocked: deadline cannot parse drop_dead=$drop_dead"; return 1; }
    printf '%s\n' "$epoch"
}

_queue_deadline_job_file() {
    local id="${QUEUEBASH_CLASS_JOB_ID:-${JOB_ID:-}}" root="${QUEUEBASH_ROOT:-${HOME:-}/.queuebash}" st f
    [[ -n "$id" ]] || return 1
    for st in pending running paused done failed pol_block policy_blocked interrupted cancelled deleted; do
        f="$root/$st/$id.job"
        [[ -f "$f" ]] && { printf '%s\n' "$f"; return 0; }
    done
    return 1
}

_queue_deadline_job_command_summary() {
    local i n part out=""
    n="${QUEUEBASH_COMMAND_COUNT:-0}"
    [[ "$n" =~ ^[0-9]+$ ]] || n=0
    for ((i=0; i<n; i++)); do
        part="QUEUEBASH_COMMAND_$i"
        out+=" ${!part:-}"
    done
    printf '%s\n' "${out# }"
}

_queue_deadline_history_durations() {
    local pattern="${1:-standard}" job_name="${QUEUEBASH_CLASS_JOB_NAME:-${JOB_NAME:-}}" root="${QUEUEBASH_ROOT:-${HOME:-}/.queuebash}"
    local f dur started finished dom
    [[ -n "$job_name" ]] || return 0
    shopt -s nullglob
    for f in "$root"/done/*.job; do
        [[ -f "$f" ]] || continue
        (
            JOB_NAME=""; EXEC_DURATION=""; EXEC_STARTED_AT=""; EXEC_FINISHED_AT=""; STARTED_AT=""; FINISHED_AT=""; COMMAND=()
            source "$f" >/dev/null 2>&1 || exit 0
            [[ "${JOB_NAME:-}" == "$job_name" ]] || exit 0
            dur="${EXEC_DURATION:-}"
            if [[ ! "$dur" =~ ^[0-9]+$ || "$dur" -le 0 ]]; then
                started="${EXEC_STARTED_AT:-${STARTED_AT:-}}"
                finished="${EXEC_FINISHED_AT:-${FINISHED_AT:-}}"
                if [[ "$started" =~ ^[0-9]+$ && "$finished" =~ ^[0-9]+$ && "$finished" -gt "$started" ]]; then
                    dur=$((finished - started))
                else
                    exit 0
                fi
            fi
            case "$pattern" in
                month-end|month_end|monthend)
                    finished="${EXEC_FINISHED_AT:-${FINISHED_AT:-}}"
                    if [[ "$finished" =~ ^[0-9]+$ ]]; then
                        dom="$(date -d "@$finished" +%d 2>/dev/null || true)"
                    else
                        dom="$(date -r "$f" +%d 2>/dev/null || true)"
                    fi
                    [[ "$dom" =~ ^[0-9]+$ && $((10#$dom)) -ge 28 ]] || exit 0
                    ;;
            esac
            printf '%s\n' "$dur"
        )
    done
    shopt -u nullglob
}

_queue_deadline_median() {
    awk '
        /^[0-9]+$/ && $1 > 0 { a[++n]=$1 }
        END {
            if (n < 1) exit 1
            for (i=1; i<=n; i++) for (j=i+1; j<=n; j++) if (a[j] < a[i]) { t=a[i]; a[i]=a[j]; a[j]=t }
            if (n % 2) print a[(n+1)/2]
            else print int((a[n/2] + a[n/2+1]) / 2)
        }'
}

_queue_deadline_expected_seconds() {
    local pattern="$1" margin_pct="$2" min_samples="$3" fallback_raw="$4" median="" count fallback
    count="$(_queue_deadline_history_durations "$pattern" | awk 'END{print NR+0}')"
    if [[ "$count" =~ ^[0-9]+$ && "$count" -ge "$min_samples" ]]; then
        median="$(_queue_deadline_history_durations "$pattern" | _queue_deadline_median || true)"
    fi
    if [[ ! "$median" =~ ^[0-9]+$ || "$median" -le 0 ]]; then
        fallback="$(_queue_deadline_duration_seconds "$fallback_raw" 2>/dev/null || true)"
        [[ "$fallback" =~ ^[0-9]+$ && "$fallback" -gt 0 ]] || { echo "asset_check_blocked: deadline insufficient history and invalid fallback_duration=$fallback_raw"; return 1; }
        median="$fallback"
        count=0
    fi
    [[ "$margin_pct" =~ ^[0-9]+$ ]] || margin_pct=0
    _QUEUE_DEADLINE_SAMPLE_COUNT="$count"
    _QUEUE_DEADLINE_MEDIAN_SECONDS="$median"
    printf '%s\n' "$(( median + (median * margin_pct + 99) / 100 ))"
}


_queue_deadline_truthy() {
    case "${1:-}" in
        1|yes|YES|true|TRUE|on|ON|y|Y) return 0 ;;
    esac
    return 1
}

_queue_deadline_live_worker_count() {
    local root="${QUEUEBASH_ROOT:-${HOME:-}/.queuebash}" pf pid count=0
    mkdir -p "$root/workers" 2>/dev/null || true
    shopt -s nullglob
    for pf in "$root"/workers/*.pid; do
        [[ -f "$pf" ]] || continue
        pid="$(cat "$pf" 2>/dev/null || true)"
        if [[ "$pid" =~ ^[0-9]+$ && -d "/proc/$pid" ]]; then
            count=$((count + 1))
        else
            rm -f -- "$pf" 2>/dev/null || true
        fi
    done
    shopt -u nullglob
    printf '%s\n' "$count"
}

_queue_deadline_running_job_count() {
    local root="${QUEUEBASH_ROOT:-${HOME:-}/.queuebash}" f count=0
    shopt -s nullglob
    for f in "$root"/running/*.job; do
        [[ -f "$f" ]] && count=$((count + 1))
    done
    shopt -u nullglob
    printf '%s\n' "$count"
}

_queue_deadline_maybe_start_extra_worker() {
    local reason="$1" slack="$2" start_flag start_slack max_extra root id marker pid count pf live_workers running_jobs all_busy
    shift 2 || true

    start_flag="$(_queue_deadline_param start_worker "$@" || true)"
    [[ -n "$start_flag" ]] || start_flag="${CLASS_DEADLINE_ALLOW_EXTRA_WORKER:-0}"
    _queue_deadline_truthy "$start_flag" || return 0

    start_slack="$(_queue_deadline_param start_worker_slack "$@" || echo "${CLASS_DEADLINE_EXTRA_WORKER_SLACK:-0}")"
    [[ "$start_slack" =~ ^-?[0-9]+$ ]] || start_slack=0
    [[ "$slack" =~ ^-?[0-9]+$ ]] || return 0
    (( slack <= start_slack )) || return 0

    max_extra="$(_queue_deadline_param max_extra_workers "$@" || echo "${CLASS_DEADLINE_MAX_EXTRA_WORKERS:-1}")"
    [[ "$max_extra" =~ ^[0-9]+$ ]] || max_extra=1
    (( max_extra > 0 )) || return 0

    root="${QUEUEBASH_ROOT:-${HOME:-}/.queuebash}"
    id="${QUEUEBASH_CLASS_JOB_ID:-${JOB_ID:-}}"
    [[ -n "$id" ]] || return 0
    mkdir -p "$root/workers" 2>/dev/null || return 0

    count=0
    shopt -s nullglob
    for pf in "$root"/workers/deadline_extra_*.pid; do
        [[ -f "$pf" ]] || continue
        pid="$(cat "$pf" 2>/dev/null || true)"
        if [[ "$pid" =~ ^[0-9]+$ && -d "/proc/$pid" ]]; then
            count=$((count + 1))
        else
            rm -f -- "$pf" 2>/dev/null || true
        fi
    done
    shopt -u nullglob
    (( count < max_extra )) || return 0

    marker="$root/workers/deadline_extra_${id}.pid"
    if [[ -f "$marker" ]]; then
        pid="$(cat "$marker" 2>/dev/null || true)"
        [[ "$pid" =~ ^[0-9]+$ && -d "/proc/$pid" ]] && return 0
        rm -f -- "$marker" 2>/dev/null || true
    fi

    # Only add capacity when the recorded worker set appears saturated.  Foreground
    # workers are not always recorded, so a non-zero running count with zero recorded
    # workers is treated as saturated/unknown and may start one bounded helper.
    live_workers="$(_queue_deadline_live_worker_count)"
    running_jobs="$(_queue_deadline_running_job_count)"
    all_busy=0
    if (( live_workers > 0 && running_jobs >= live_workers )); then
        all_busy=1
    elif (( live_workers == 0 && running_jobs > 0 )); then
        all_busy=1
    fi
    (( all_busy == 1 )) || return 0

    if declare -F _queue_worker >/dev/null 2>&1; then
        (_queue_worker "deadline-${id}") &
        pid="$!"
    elif declare -F queue >/dev/null 2>&1; then
        (queue start --workers 1 >/dev/null 2>&1) &
        pid="$!"
    else
        echo "asset_check_ok: deadline extra worker not started reason=no_worker_entrypoint"
        return 0
    fi

    printf '%s\n' "$pid" > "$marker" 2>/dev/null || true
    printf '%s\n' "$pid" > "$root/workers/worker_${pid}.pid" 2>/dev/null || true

    local f
    f="$(_queue_deadline_job_file 2>/dev/null || true)"
    if [[ -n "$f" && -w "$f" ]]; then
        {
            printf 'DEADLINE_EXTRA_WORKER_STARTED_AT=%q\n' "$(date -Is 2>/dev/null || date)"
            printf 'DEADLINE_EXTRA_WORKER_PID=%q\n' "$pid"
            printf 'DEADLINE_EXTRA_WORKER_REASON=%q\n' "$reason slack=${slack}s running=${running_jobs} workers=${live_workers}"
        } >> "$f" 2>/dev/null || true
    fi

    echo "asset_check_ok: deadline started extra worker pid=$pid reason=$reason slack=${slack}s running=${running_jobs} workers=${live_workers} max_extra=${max_extra}"
}

_queue_deadline_set_priority() {
    local new_pri="$1" why="$2" f cur id
    f="$(_queue_deadline_job_file 2>/dev/null || true)"
    [[ -n "$f" && -w "$f" ]] || return 0
    cur="$(grep '^PRIORITY=' "$f" 2>/dev/null | head -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null || echo 10)"
    [[ "$cur" =~ ^-?[0-9]+$ ]] || cur=10
    # bashqueues lower number normally runs first, but this project has been using
    # larger priority numbers for operator-visible urgency.  Keep the sysadmin
    # requested behaviour: only raise the visible priority number.
    if (( cur < new_pri )); then
        if grep -q '^PRIORITY=' "$f"; then
            sed -i "s/^PRIORITY=.*/PRIORITY=$new_pri/" "$f"
        else
            sed -i "/^JOB_NAME=/a PRIORITY=$new_pri" "$f"
        fi
        id="$(basename "$f" .job)"
        {
            printf 'DEADLINE_ESCALATED_AT=%q\n' "$(date -Is 2>/dev/null || date)"
            printf 'DEADLINE_ESCALATED_PRIORITY=%q\n' "$new_pri"
            printf 'DEADLINE_ESCALATED_REASON=%q\n' "$why"
        } >> "$f" 2>/dev/null || true
        echo "asset_check_ok: deadline priority escalated job=$id priority=$new_pri reason=$why"
    fi
}

_queue_deadline_add_exception() {
    local asset="$1" reason="$2" id root dir file now by
    id="${QUEUEBASH_CLASS_JOB_ID:-${JOB_ID:-}}"
    root="${QUEUEBASH_ROOT:-${HOME:-}/.queuebash}"
    [[ -n "$id" && -n "$asset" ]] || return 0
    dir="$root/exceptions"; file="$dir/$id.env"
    mkdir -p "$dir" 2>/dev/null || return 0
    now="$(date -Is 2>/dev/null || date)"
    by="deadline:panic"
    if [[ -f "$file" ]] && grep -Fq "$asset" "$file" 2>/dev/null; then
        return 0
    fi
    printf '%s\t%s\t%s\t%s\n' "$asset" "$reason" "$now" "$by" >> "$file" 2>/dev/null || true
    echo "asset_check_ok: deadline panic applied fallback asset exception asset=$asset reason=$reason"
}

_queue_deadline_calculate() {
    local facility="$1" target="$2" drop_dead margin pattern min_samples fallback now deadline expected pnr slack
    shift 2 || true
    drop_dead="$(_queue_deadline_param drop_dead "$@" || true)"
    margin="$(_queue_deadline_param margin_pct "$@" || echo 15)"
    pattern="$(_queue_deadline_param pattern "$@" || echo standard)"
    min_samples="$(_queue_deadline_param min_samples "$@" || echo 1)"
    fallback="$(_queue_deadline_param fallback_duration "$@" || echo 60m)"
    [[ "$min_samples" =~ ^[0-9]+$ ]] || min_samples=1
    now="$(_queue_deadline_now_epoch "$@")" || return 1
    deadline="$(_queue_deadline_drop_dead_epoch "$drop_dead" "$now")" || return 1
    expected="$(_queue_deadline_expected_seconds "$pattern" "$margin" "$min_samples" "$fallback")" || return 1
    pnr=$((deadline - expected))
    slack=$((pnr - now))
    _QUEUE_DEADLINE_NOW="$now"
    _QUEUE_DEADLINE_DEADLINE="$deadline"
    _QUEUE_DEADLINE_EXPECTED="$expected"
    _QUEUE_DEADLINE_PNR="$pnr"
    _QUEUE_DEADLINE_SLACK="$slack"
    printf 'asset_check_ok: %s target=%s slack=%ss expected=%ss median=%ss samples=%s deadline=%s pnr=%s command=%s\n' \
        "$facility" "${target:-deadline}" "$slack" "$expected" "${_QUEUE_DEADLINE_MEDIAN_SECONDS:-unknown}" "${_QUEUE_DEADLINE_SAMPLE_COUNT:-0}" "$deadline" "$pnr" "$(_queue_deadline_job_command_summary)"
    return 0
}

queue_asset_check_deadline_monitor() {
    local target="$1" warn_slack warn_priority critical_priority slack
    shift || true
    warn_slack="$(_queue_deadline_param warn_slack "$@" || echo 3600)"
    warn_priority="$(_queue_deadline_param warn_priority "$@" || echo 50)"
    critical_priority="$(_queue_deadline_param critical_priority "$@" || echo 99)"
    _queue_deadline_calculate "deadline:monitor" "$target" "$@" || return 1
    slack="${_QUEUE_DEADLINE_SLACK:-0}"
    [[ "$warn_slack" =~ ^[0-9]+$ ]] || warn_slack=3600
    [[ "$warn_priority" =~ ^-?[0-9]+$ ]] || warn_priority=50
    [[ "$critical_priority" =~ ^-?[0-9]+$ ]] || critical_priority=99
    if (( slack <= 0 )); then
        _queue_deadline_set_priority "$critical_priority" "critical_slack=${slack}s"
        _queue_deadline_maybe_start_extra_worker "critical_slack" "$slack" "$@"
    elif (( slack <= warn_slack )); then
        _queue_deadline_set_priority "$warn_priority" "low_slack=${slack}s"
        _queue_deadline_maybe_start_extra_worker "low_slack" "$slack" "$@"
    fi
    return 0
}

queue_asset_check_deadline_panic() {
    local target="$1" critical_priority fallback_assets panic_assets asset reason slack
    shift || true
    critical_priority="$(_queue_deadline_param critical_priority "$@" || echo 99)"
    panic_assets="$(_queue_deadline_param panic_assets "$@" || true)"
    fallback_assets="${CLASS_DEADLINE_FALLBACK_ASSETS:-$panic_assets}"
    _queue_deadline_calculate "deadline:panic" "$target" "$@" || return 1
    slack="${_QUEUE_DEADLINE_SLACK:-0}"
    [[ "$critical_priority" =~ ^-?[0-9]+$ ]] || critical_priority=99
    if (( slack <= 0 )); then
        _queue_deadline_set_priority "$critical_priority" "panic_slack=${slack}s"
        _queue_deadline_maybe_start_extra_worker "panic_slack" "$slack" "$@"
        reason="deadline panic: point of no return crossed slack=${slack}s expected=${_QUEUE_DEADLINE_EXPECTED:-unknown}s"
        for asset in $fallback_assets; do
            _queue_deadline_add_exception "$asset" "$reason"
        done
    fi
    return 0
}
