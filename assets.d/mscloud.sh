#!/usr/bin/env bash
# bashqueues Microsoft cloud file services asset checks (SharePoint / OneDrive via Graph)

_MSCLOUD_TIMEOUT="${MSCLOUD_TIMEOUT:-10}"

queue_asset_facilities() {
    cat <<'FACILITIES'
mscloud:sharepoint_access	Validates access to a SharePoint site through Microsoft Graph
mscloud:onedrive_file_exists	Validates that a OneDrive file exists through Microsoft Graph
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
mscloud:sharepoint_access	target=site-id	params=access_token=...|env_file=/path/env env_key=GRAPH_TOKEN timeout=10	example=queue_class_shared_asset mscloud sharepoint_access example.sharepoint.com,root env_file=/run/queuebash/graph.env env_key=GRAPH_TOKEN	notes=Calls Graph /sites/{site-id}; fails closed on missing token or HTTP failure.
mscloud:onedrive_file_exists	target=/path/in/drive	params=user_id=me|user@domain access_token=...|env_file=/path/env env_key=GRAPH_TOKEN timeout=10	example=queue_class_shared_asset mscloud onedrive_file_exists /Documents/report.xlsx user_id=me env_file=/run/queuebash/graph.env env_key=GRAPH_TOKEN	notes=Calls Graph drive/root:{path}; target should start with /.
EOF_HINTS
}

_queue_asset_mscloud_param() { queue_asset_param "$@"; }
_queue_asset_mscloud_get_token() {
    local access_token env_file env_key
    access_token="$(_queue_asset_mscloud_param access_token "$@" || true)"
    env_file="$(_queue_asset_mscloud_param env_file "$@" || true)"
    env_key="$(_queue_asset_mscloud_param env_key "$@" || true)"
    if [[ -n "$env_file" && -r "$env_file" && -n "$env_key" ]]; then
        access_token="$(grep -E "^${env_key}=" "$env_file" | head -n1 | cut -d= -f2- | sed 's/^"//; s/"$//')"
    fi
    [[ -n "$access_token" ]] && printf '%s\n' "$access_token"
}

queue_asset_check_mscloud_sharepoint_access() {
    local token="$1" site_id="$2"; shift 2 || true
    local access_token timeout
    timeout="$(_queue_asset_mscloud_param timeout "$@" || echo "$_MSCLOUD_TIMEOUT")"
    access_token="$(_queue_asset_mscloud_get_token "$@")"
    if ! command -v curl >/dev/null 2>&1; then
        echo "asset_check_blocked: mscloud:sharepoint_access requires curl"
        return 1
    fi
    if [[ -z "$access_token" || -z "$site_id" ]]; then
        echo "asset_check_blocked: mscloud:sharepoint_access requires target=site_id and access_token=/env_file=/env_key="
        return 1
    fi
    if timeout "$timeout" curl -fsS -H "Authorization: Bearer $access_token" "https://graph.microsoft.com/v1.0/sites/$site_id" >/dev/null 2>&1; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: mscloud:sharepoint_access Graph call failed for site_id=$site_id"
    return 1
}

queue_asset_check_mscloud_onedrive_file_exists() {
    local token="$1" item_path="$2"; shift 2 || true
    local access_token timeout user_id
    timeout="$(_queue_asset_mscloud_param timeout "$@" || echo "$_MSCLOUD_TIMEOUT")"
    user_id="$(_queue_asset_mscloud_param user_id "$@" || echo "me")"
    access_token="$(_queue_asset_mscloud_get_token "$@")"
    if ! command -v curl >/dev/null 2>&1; then
        echo "asset_check_blocked: mscloud:onedrive_file_exists requires curl"
        return 1
    fi
    if [[ -z "$access_token" || -z "$item_path" ]]; then
        echo "asset_check_blocked: mscloud:onedrive_file_exists requires target=/path and access_token=/env_file=/env_key="
        return 1
    fi
    local url
    if [[ "$user_id" == "me" ]]; then
        url="https://graph.microsoft.com/v1.0/me/drive/root:$item_path"
    else
        url="https://graph.microsoft.com/v1.0/users/$user_id/drive/root:$item_path"
    fi
    if timeout "$timeout" curl -fsS -H "Authorization: Bearer $access_token" "$url" >/dev/null 2>&1; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: mscloud:onedrive_file_exists missing or inaccessible: $item_path"
    return 1
}
