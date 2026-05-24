#!/usr/bin/env bash
# bashqueues asset plugin: time window / restricted dispatch windows

queue_asset_facilities() {
    cat <<'EOF'
time:window Checks that the current local time is inside an allowed dispatch window
EOF
}

queue_asset_hints() {
    cat <<'EOF'
time:window	target=policy name	params=weekdays=mon-fri weekday_windows=18:00-05:00 weekends=sat-sun weekend_windows=always	example=queue_class_shared_asset time window "overnight" weekdays=mon-fri weekday_windows=18:00-05:00 weekends=sat-sun weekend_windows=always	notes=Blocks dispatch outside allowed windows. now_epoch is a test-only asset parameter and is intentionally not offered by the Class Creator for production restrictions. Use a separate exception class to omit this restriction explicitly.
EOF
}

_queue_time_param() {
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

_queue_time_lower() {
    tr '[:upper:]' '[:lower:]'
}

_queue_time_day_num() {
    local epoch="${1:-}"
    if [[ -n "$epoch" ]]; then
        date -d "@$epoch" +%u
    else
        date +%u
    fi
}

_queue_time_day_label() {
    local epoch="${1:-}"
    if [[ -n "$epoch" ]]; then
        LC_ALL=C date -d "@$epoch" +%a
    else
        LC_ALL=C date +%a
    fi
}

_queue_time_hhmm_label() {
    local epoch="${1:-}"
    if [[ -n "$epoch" ]]; then
        LC_ALL=C date -d "@$epoch" +%H:%M
    else
        LC_ALL=C date +%H:%M
    fi
}

_queue_time_hhmm_minutes() {
    local hhmm="$1"
    local h m

    [[ "$hhmm" =~ ^([0-9]{1,2}):([0-9]{2})$ ]] || return 1
    h="${BASH_REMATCH[1]}"
    m="${BASH_REMATCH[2]}"
    (( h >= 0 && h <= 23 && m >= 0 && m <= 59 )) || return 1
    echo $((10#$h * 60 + 10#$m))
}

_queue_time_now_minutes() {
    local epoch="${1:-}"
    local hh mm
    if [[ -n "$epoch" ]]; then
        hh="$(date -d "@$epoch" +%H)"
        mm="$(date -d "@$epoch" +%M)"
    else
        hh="$(date +%H)"
        mm="$(date +%M)"
    fi
    echo $((10#$hh * 60 + 10#$mm))
}

_queue_time_day_in_set() {
    local day="$1"
    local spec="${2:-}"
    local token n

    spec="$(printf '%s' "$spec" | _queue_time_lower)"
    spec="${spec// /}"
    [[ -n "$spec" ]] || return 1

    case "$spec" in
        all|any|daily|everyday) return 0 ;;
        weekdays|weekday|mon-fri|monday-friday) (( day >= 1 && day <= 5 )); return $? ;;
        weekends|weekend|sat-sun|saturday-sunday) (( day == 6 || day == 7 )); return $? ;;
    esac

    IFS=',' read -r -a parts <<< "$spec"
    for token in "${parts[@]}"; do
        case "$token" in
            mon|monday) n=1 ;;
            tue|tues|tuesday) n=2 ;;
            wed|wednesday) n=3 ;;
            thu|thur|thurs|thursday) n=4 ;;
            fri|friday) n=5 ;;
            sat|saturday) n=6 ;;
            sun|sunday) n=7 ;;
            *) n="" ;;
        esac
        [[ -n "$n" && "$day" -eq "$n" ]] && return 0
    done

    return 1
}

_queue_time_minutes_in_window() {
    local now="$1"
    local window="$2"
    local start end a b

    [[ "$window" =~ ^([^,-]+)-([^,-]+)$ ]] || return 1
    start="${BASH_REMATCH[1]}"
    end="${BASH_REMATCH[2]}"

    a="$(_queue_time_hhmm_minutes "$start")" || return 1
    b="$(_queue_time_hhmm_minutes "$end")" || return 1

    if (( a <= b )); then
        (( now >= a && now < b ))
    else
        (( now >= a || now < b ))
    fi
}

_queue_time_in_any_window() {
    local now="$1"
    local spec="${2:-}"
    local w

    spec="${spec// /}"
    [[ -n "$spec" ]] || return 1
    case "$(printf '%s' "$spec" | _queue_time_lower)" in
        always|any|all|24h|24x7) return 0 ;;
        never|none) return 1 ;;
    esac

    IFS=',' read -r -a windows <<< "$spec"
    for w in "${windows[@]}"; do
        _queue_time_minutes_in_window "$now" "$w" && return 0
    done
    return 1
}

queue_asset_check_time_window() {
    local policy="${1:-time-window}"
    shift || true

    local weekdays weekday_windows weekends weekend_windows now_epoch day now_m
    local day_name now_hm

    weekdays="$(_queue_time_param weekdays "$@" || echo mon-fri)"
    weekday_windows="$(_queue_time_param weekday_windows "$@" || _queue_time_param windows "$@" || echo always)"
    weekends="$(_queue_time_param weekends "$@" || echo sat-sun)"
    weekend_windows="$(_queue_time_param weekend_windows "$@" || echo always)"
    now_epoch="$(_queue_time_param now_epoch "$@" || echo "${QUEUEBASH_TIME_NOW_EPOCH:-}")"

    day="$(_queue_time_day_num "$now_epoch")" || {
        echo "asset_check_blocked: time:window cannot_determine_day policy=$policy"
        return 1
    }
    now_m="$(_queue_time_now_minutes "$now_epoch")" || {
        echo "asset_check_blocked: time:window cannot_determine_time policy=$policy"
        return 1
    }

    day_name="$(_queue_time_day_label "$now_epoch" 2>/dev/null || echo "day$day")"
    now_hm="$(_queue_time_hhmm_label "$now_epoch" 2>/dev/null || echo "$now_m")"

    if _queue_time_day_in_set "$day" "$weekdays"; then
        if _queue_time_in_any_window "$now_m" "$weekday_windows"; then
            echo "asset_check_ok: time:window policy=$policy day=$day_name time=$now_hm matched=weekday window=$weekday_windows"
            return 0
        fi
        echo "asset_check_blocked: time:window outside_allowed_window policy=$policy day=$day_name time=$now_hm allowed_days=$weekdays allowed_windows=$weekday_windows"
        return 1
    fi

    if _queue_time_day_in_set "$day" "$weekends"; then
        if _queue_time_in_any_window "$now_m" "$weekend_windows"; then
            echo "asset_check_ok: time:window policy=$policy day=$day_name time=$now_hm matched=weekend window=$weekend_windows"
            return 0
        fi
        echo "asset_check_blocked: time:window outside_allowed_window policy=$policy day=$day_name time=$now_hm allowed_days=$weekends allowed_windows=$weekend_windows"
        return 1
    fi

    echo "asset_check_blocked: time:window day_not_allowed policy=$policy day=$day_name time=$now_hm weekdays=$weekdays weekends=$weekends"
    return 1
}
