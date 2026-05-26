#!/usr/bin/env bash
# bashqueues Microsoft Teams asset checks

_TEAMS_TIMEOUT="${TEAMS_TIMEOUT:-10}"

queue_asset_facilities() {
    cat <<'FACILITIES'
teams:webhook_alive	Optionally validates a Teams incoming webhook by posting a connectivity message
teams:graph_presence	Validates that a user's Teams presence can be queried through Graph
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
teams:webhook_alive	target=webhook_url	params=allow_post=1 timeout=10 text=...	example=queue_class_shared_asset teams webhook_alive https://... allow_post=1	notes=Side-effecting probe; fails closed unless allow_post=1 is explicitly supplied.
teams:graph_presence	target=user@domain	params=access_token=...|env_file=/path/env env_key=GRAPH_TOKEN timeout=10	example=queue_class_shared_asset teams graph_presence user@example.com env_file=/run/queuebash/graph.env env_key=GRAPH_TOKEN	notes=Calls Graph /users/{upn}/presence.
EOF_HINTS
}

_queue_asset_teams_param() { queue_asset_param "$@"; }
_queue_asset_teams_get_token() {
    local access_token env_file env_key
    access_token="$(_queue_asset_teams_param access_token "$@" || true)"
    env_file="$(_queue_asset_teams_param env_file "$@" || true)"
    env_key="$(_queue_asset_teams_param env_key "$@" || true)"
    if [[ -n "$env_file" && -r "$env_file" && -n "$env_key" ]]; then
        access_token="$(grep -E "^${env_key}=" "$env_file" | head -n1 | cut -d= -f2- | sed 's/^"//; s/"$//')"
    fi
    [[ -n "$access_token" ]] && printf '%s\n' "$access_token"
}

queue_asset_check_teams_webhook_alive() {
    local token="$1" webhook_url="$2"; shift 2 || true
    local timeout allow_post text payload
    timeout="$(_queue_asset_teams_param timeout "$@" || echo "$_TEAMS_TIMEOUT")"
    allow_post="$(_queue_asset_teams_param allow_post "$@" || echo "0")"
    text="$(_queue_asset_teams_param text "$@" || echo "queuebash connectivity test")"
    if [[ "$allow_post" != "1" ]]; then
        echo "asset_check_blocked: teams:webhook_alive requires explicit allow_post=1 because it posts to Teams"
        return 1
    fi
    if ! command -v curl >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1; then
        echo "asset_check_blocked: teams:webhook_alive requires curl and python3"
        return 1
    fi
    if [[ -z "$webhook_url" ]]; then
        echo "asset_check_blocked: teams:webhook_alive requires target=webhook_url"
        return 1
    fi
    payload="$(QB_TEXT="$text" python3 - <<'PY'
import json, os
print(json.dumps({"text": os.environ.get("QB_TEXT", "queuebash connectivity test")}))
PY
)"
    if timeout "$timeout" curl -fsS -H "Content-Type: application/json" -d "$payload" "$webhook_url" >/dev/null 2>&1; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: teams:webhook_alive POST failed"
    return 1
}

queue_asset_check_teams_graph_presence() {
    local token="$1" upn="$2"; shift 2 || true
    local access_token timeout
    timeout="$(_queue_asset_teams_param timeout "$@" || echo "$_TEAMS_TIMEOUT")"
    access_token="$(_queue_asset_teams_get_token "$@")"
    if ! command -v curl >/dev/null 2>&1; then
        echo "asset_check_blocked: teams:graph_presence requires curl"
        return 1
    fi
    if [[ -z "$access_token" || -z "$upn" ]]; then
        echo "asset_check_blocked: teams:graph_presence requires target=user@domain and access_token=/env_file=/env_key="
        return 1
    fi
    if timeout "$timeout" curl -fsS -H "Authorization: Bearer $access_token" "https://graph.microsoft.com/v1.0/users/$upn/presence" >/dev/null 2>&1; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: teams:graph_presence failed for $upn"
    return 1
}
