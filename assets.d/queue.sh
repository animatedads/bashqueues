#!/usr/bin/env bash
# bashqueues queue-history asset checks
#
# Facilities published:
#   queue:command_has_run
#   queue:command_has_not_run
#   queue:job_has_run
#   queue:job_has_not_run

queue_asset_facilities() {
    cat <<'FACILITIES'
queue:command_has_not_run	Check no matching queue job command/name has run within the time window
queue:command_has_run	Check a matching queue job command/name has run within the time window
queue:job_has_not_run	Alias: check no matching queue job command/name has run within the time window
queue:job_has_run	Alias: check a matching queue job command/name has run within the time window
FACILITIES
}

queue_asset_hints() {
    cat <<'HINTS'
queue:command_has_run	target=job name or command/process pattern	params=match=exact|substr|regex field=command|name|both time=24h states=done,failed,running,pending	example=queue_class_shared_asset queue command_has_run "nightly_export.sh" match=substr time=24h	notes=History check. Passes when a matching job record has RUN_STARTED_AT or EXEC_FINISHED_AT inside the requested time window. This is different from proc:running, which checks current OS processes.
queue:command_has_not_run	target=job name or command/process pattern	params=match=exact|substr|regex field=command|name|both time=24h states=done,failed,running,pending	example=queue_class_shared_asset queue command_has_not_run "nightly_export.sh" match=substr time=24h	notes=Anti-history check. Passes only when no matching job record has run inside the requested time window. Useful for once-per-period guards.
queue:job_has_run	target=job name or command/process pattern	params=match=exact|substr|regex field=command|name|both time=24h states=done,failed,running,pending	example=queue_class_shared_asset queue job_has_run "backup" field=name match=exact time=24h	notes=Alias for queue:command_has_run with wording that is friendlier for job-name checks.
queue:job_has_not_run	target=job name or command/process pattern	params=match=exact|substr|regex field=command|name|both time=24h states=done,failed,running,pending	example=queue_class_shared_asset queue job_has_not_run "backup" field=name match=exact time=24h	notes=Alias for queue:command_has_not_run with wording that is friendlier for job-name checks.
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

_queue_asset_queue_root() {
    printf '%s\n' "${QUEUEBASH_ROOT:-$HOME/.queuebash}"
}

_queue_asset_queue_duration_seconds() {
    local raw="${1:-24h}"
    case "$raw" in
        '' ) echo 86400 ;;
        *[!0-9smhdwSMHDW]* ) echo 86400 ;;
        *[sS]) echo "${raw%[sS]}" ;;
        *[mM]) echo $(( ${raw%[mM]} * 60 )) ;;
        *[hH]) echo $(( ${raw%[hH]} * 3600 )) ;;
        *[dD]) echo $(( ${raw%[dD]} * 86400 )) ;;
        *[wW]) echo $(( ${raw%[wW]} * 604800 )) ;;
        * ) echo "$raw" ;;
    esac
}

_queue_asset_queue_epoch() {
    local ts="$1"
    [[ -n "$ts" ]] || return 1
    date -d "$ts" +%s 2>/dev/null || return 1
}

_queue_asset_queue_match_text() {
    local pattern="$1" text="$2" match="$3"
    case "$match" in
        exact) [[ "$text" == "$pattern" ]] ;;
        regex) [[ "$text" =~ $pattern ]] ;;
        substr|*) [[ "$text" == *"$pattern"* ]] ;;
    esac
}

_queue_asset_queue_state_allowed() {
    local state="$1" states_csv="$2"
    [[ -n "$state" ]] || return 1
    [[ -z "$states_csv" || "$states_csv" == "all" || "$states_csv" == "*" ]] && return 0
    local IFS=',' s
    for s in $states_csv; do
        [[ "$state" == "$s" ]] && return 0
    done
    return 1
}

_queue_asset_queue_command_string_from_file() {
    local file="$1"
    (
        COMMAND=()
        source "$file" 2>/dev/null || exit 0
        if declare -p COMMAND >/dev/null 2>&1; then
            printf '%s' "${COMMAND[*]}"
        fi
    )
}

_queue_asset_queue_find_recent_match() {
    local target="$1"
    shift || true
    local match field time_s states root now cutoff state_dir file state job_name command_text ts epoch qid

    match="$(queue_asset_param match "$@" || echo substr)"
    field="$(queue_asset_param field "$@" || echo both)"
    time_s="$(_queue_asset_queue_duration_seconds "$(queue_asset_param time "$@" || echo 24h)")"
    states="$(queue_asset_param states "$@" || echo done,failed,running,pending,interrupted,cancelled)"
    root="$(_queue_asset_queue_root)"
    now="$(date +%s)"
    cutoff=$(( now - time_s ))

    for state_dir in done failed running pending interrupted cancelled deleted; do
        _queue_asset_queue_state_allowed "$state_dir" "$states" || continue
        [[ -d "$root/$state_dir" ]] || continue
        for file in "$root/$state_dir"/*.job; do
            [[ -f "$file" ]] || continue
            job_name="$(grep '^JOB_NAME=' "$file" 2>/dev/null | head -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null || true)"
            command_text="$(_queue_asset_queue_command_string_from_file "$file")"

            case "$field" in
                name)
                    _queue_asset_queue_match_text "$target" "$job_name" "$match" || continue
                    ;;
                command)
                    _queue_asset_queue_match_text "$target" "$command_text" "$match" || continue
                    ;;
                both|*)
                    _queue_asset_queue_match_text "$target" "$job_name" "$match" || _queue_asset_queue_match_text "$target" "$command_text" "$match" || continue
                    ;;
            esac

            ts="$(grep '^EXEC_FINISHED_AT=' "$file" 2>/dev/null | tail -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null || true)"
            [[ -n "$ts" ]] || ts="$(grep '^RUN_STARTED_AT=' "$file" 2>/dev/null | tail -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null || true)"
            [[ -n "$ts" ]] || ts="$(grep '^SUBMITTED_AT=' "$file" 2>/dev/null | tail -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null || true)"
            epoch="$(_queue_asset_queue_epoch "$ts" || true)"
            [[ "$epoch" =~ ^[0-9]+$ ]] || continue
            (( epoch >= cutoff )) || continue

            qid="$(basename "$file" .job)"
            printf '%s\t%s\t%s\t%s\t%s\n' "$qid" "$state_dir" "$job_name" "$ts" "$command_text"
            return 0
        done
    done
    return 1
}

queue_asset_check_queue_command_has_run() {
    local target="$1" match_line time_value
    shift || true
    time_value="$(queue_asset_param time "$@" || echo 24h)"
    if match_line="$(_queue_asset_queue_find_recent_match "$target" "$@")"; then
        local qid state name ts cmd
        IFS=$'\t' read -r qid state name ts cmd <<< "$match_line"
        echo "asset_check_ok: queue:command_has_run target=$target time=$time_value qid=$qid state=$state job_name=$name at=$ts"
        return 0
    fi
    echo "asset_check_blocked: queue:command_has_run target=$target time=$time_value no_recent_match=1"
    return 1
}

queue_asset_check_queue_command_has_not_run() {
    local target="$1" match_line time_value
    shift || true
    time_value="$(queue_asset_param time "$@" || echo 24h)"
    if match_line="$(_queue_asset_queue_find_recent_match "$target" "$@")"; then
        local qid state name ts cmd
        IFS=$'\t' read -r qid state name ts cmd <<< "$match_line"
        echo "asset_check_blocked: queue:command_has_not_run target=$target time=$time_value matched_qid=$qid state=$state job_name=$name at=$ts"
        return 1
    fi
    echo "asset_check_ok: queue:command_has_not_run target=$target time=$time_value no_recent_match=1"
    return 0
}

queue_asset_check_queue_job_has_run() {
    queue_asset_check_queue_command_has_run "$@"
}

queue_asset_check_queue_job_has_not_run() {
    queue_asset_check_queue_command_has_not_run "$@"
}
