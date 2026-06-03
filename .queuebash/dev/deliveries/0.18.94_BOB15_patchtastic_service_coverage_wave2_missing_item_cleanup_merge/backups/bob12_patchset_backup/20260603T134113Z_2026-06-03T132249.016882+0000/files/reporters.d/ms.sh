#!/usr/bin/env bash
# bashqueues reporter plugin: Microsoft Notify (Fabric / Sentinel / Log Analytics)
#
# Disabled unless explicitly enabled through QUEUEBASH_REPORTERS and configured
# with a destination endpoint plus Entra client credentials.  Secret values are
# never written to stderr or event logs.

queue_reporter_facilities() {
    cat <<'FACILITIES'
ms:notify	Sends selected queue events to Microsoft monitoring endpoints (Fabric, Sentinel, Log Analytics)
FACILITIES
}

_queue_reporter_ms_csv_has() {
    local list="${1:-}" needle="${2:-}" item
    list="${list// /}"
    IFS=',' read -r -a _qb_ms_items <<< "$list"
    for item in "${_qb_ms_items[@]}"; do
        [[ "$item" == "$needle" || "$item" == "*" ]] && return 0
    done
    return 1
}

_queue_reporter_ms_json_escape() {
    local s="${1:-}"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

_queue_reporter_ms_bearer_from_response() {
    if command -v jq >/dev/null 2>&1; then
        jq -r '.access_token // empty' 2>/dev/null
        return $?
    fi
    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import json,sys; print(json.load(sys.stdin).get("access_token", ""))' 2>/dev/null
        return $?
    fi
    return 1
}

_queue_reporter_ms_get_token() {
    local tenant="$1" client_id="$2" secret_file="$3" scope="$4" timeout="$5"
    local secret token_url response

    [[ -r "$secret_file" ]] || return 1
    secret="$(tr -d '\r\n' < "$secret_file" 2>/dev/null || true)"
    [[ -n "$secret" ]] || return 1

    if ! command -v curl >/dev/null 2>&1; then
        return 1
    fi

    token_url="https://login.microsoftonline.com/${tenant}/oauth2/v2.0/token"
    response="$(timeout "$timeout" curl -fsS -X POST \
        --data-urlencode 'grant_type=client_credentials' \
        --data-urlencode "client_id=${client_id}" \
        --data-urlencode "client_secret=${secret}" \
        --data-urlencode "scope=${scope}" \
        "$token_url" 2>/dev/null || true)"
    [[ -n "$response" ]] || return 1

    token="$(printf '%s' "$response" | _queue_reporter_ms_bearer_from_response || true)"
    [[ -n "$token" && "$token" != "null" ]] || return 1
    printf '%s\n' "$token"
}

_queue_reporter_ms_payload() {
    local event="$1" job_id="$2" job_name="$3" state="$4" detail="$5" ts="$6" table="$7"
    if command -v jq >/dev/null 2>&1; then
        jq -n \
            --arg table "$table" \
            --arg ts "$ts" \
            --arg event "$event" \
            --arg job_id "$job_id" \
            --arg job_name "$job_name" \
            --arg state "$state" \
            --arg detail "$detail" \
            '{Table:$table,Timestamp:$ts,Event:$event,JobId:$job_id,JobName:$job_name,State:$state,Detail:$detail}'
        return $?
    fi

    printf '{"Table":"%s","Timestamp":"%s","Event":"%s","JobId":"%s","JobName":"%s","State":"%s","Detail":"%s"}\n' \
        "$(_queue_reporter_ms_json_escape "$table")" \
        "$(_queue_reporter_ms_json_escape "$ts")" \
        "$(_queue_reporter_ms_json_escape "$event")" \
        "$(_queue_reporter_ms_json_escape "$job_id")" \
        "$(_queue_reporter_ms_json_escape "$job_name")" \
        "$(_queue_reporter_ms_json_escape "$state")" \
        "$(_queue_reporter_ms_json_escape "$detail")"
}

queue_reporter_handle_event() {
    local event="${1:-}" job_id="${2:-}" job_name="${3:-}" state="${4:-}" detail="${5:-}" ts="${6:-}"
    local endpoint tenant client_id secret_file timeout events token payload table scope

    endpoint="${QUEUEBASH_MS_ENDPOINT:-}"
    tenant="${QUEUEBASH_MS_TENANT:-}"
    client_id="${QUEUEBASH_MS_CLIENT_ID:-}"
    secret_file="${QUEUEBASH_MS_CLIENT_SECRET_FILE:-}"
    timeout="${QUEUEBASH_MS_TIMEOUT:-5}"
    events="${QUEUEBASH_MS_EVENTS:-failed,pol_blocked,runtime_cap_violation,log_overflow_kill}"
    table="${QUEUEBASH_MS_TABLE:-QueuebashEvent}"
    scope="${QUEUEBASH_MS_SCOPE:-https://management.azure.com/.default}"

    [[ -n "$endpoint" && -n "$tenant" && -n "$client_id" && -n "$secret_file" ]] || return 0
    _queue_reporter_ms_csv_has "$events" "$event" || _queue_reporter_ms_csv_has "$events" "$state" || return 0

    if ! command -v curl >/dev/null 2>&1; then
        printf 'reporter_blocked: ms:notify tool_missing=curl event=%s job_id=%s\n' "$event" "$job_id" >&2
        return 1
    fi
    if ! command -v jq >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
        printf 'reporter_blocked: ms:notify tool_missing=jq|python3 event=%s job_id=%s\n' "$event" "$job_id" >&2
        return 1
    fi

    token="$(_queue_reporter_ms_get_token "$tenant" "$client_id" "$secret_file" "$scope" "$timeout")"
    if [[ -z "$token" ]]; then
        printf 'reporter_blocked: ms:notify token_error event=%s job_id=%s\n' "$event" "$job_id" >&2
        return 1
    fi

    payload="$(_queue_reporter_ms_payload "$event" "$job_id" "$job_name" "$state" "$detail" "$ts" "$table")" || return 1
    [[ -n "$payload" ]] || return 1

    timeout "$timeout" curl -fsS \
        -H "Authorization: Bearer $token" \
        -H 'Content-Type: application/json' \
        -d "$payload" \
        "$endpoint" >/dev/null 2>&1 || {
            printf 'reporter_blocked: ms:notify post_error event=%s job_id=%s\n' "$event" "$job_id" >&2
            return 1
        }
}
