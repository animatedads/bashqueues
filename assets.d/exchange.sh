#!/usr/bin/env bash
# bashqueues Exchange Online asset checks (via Microsoft Graph)

_EXCHANGE_TIMEOUT="${EXCHANGE_TIMEOUT:-10}"

queue_asset_facilities() {
    cat <<'FACILITIES'
exchange:mailbox_exists	Validates that a mailbox exists and is accessible through Graph
exchange:send_test_mail	Optionally sends a small test mail through Graph when allow_send=1
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
exchange:mailbox_exists	target=user@domain	params=access_token=...|env_file=/path/env env_key=GRAPH_TOKEN timeout=10	example=queue_class_shared_asset exchange mailbox_exists svc@example.com env_file=/run/queuebash/graph.env env_key=GRAPH_TOKEN	notes=Calls Graph mailFolders/Inbox for the target user.
exchange:send_test_mail	target=user@domain	params=allow_send=1 access_token=...|env_file=/path/env env_key=GRAPH_TOKEN subject=... body=... timeout=10	example=queue_class_shared_asset exchange send_test_mail svc@example.com allow_send=1 env_file=/run/queuebash/graph.env env_key=GRAPH_TOKEN	notes=Side-effecting probe; fails closed unless allow_send=1 is explicitly supplied.
EOF_HINTS
}

_queue_asset_exchange_param() { queue_asset_param "$@"; }
_queue_asset_exchange_get_token() {
    local access_token env_file env_key
    access_token="$(_queue_asset_exchange_param access_token "$@" || true)"
    env_file="$(_queue_asset_exchange_param env_file "$@" || true)"
    env_key="$(_queue_asset_exchange_param env_key "$@" || true)"
    if [[ -n "$env_file" && -r "$env_file" && -n "$env_key" ]]; then
        access_token="$(grep -E "^${env_key}=" "$env_file" | head -n1 | cut -d= -f2- | sed 's/^"//; s/"$//')"
    fi
    [[ -n "$access_token" ]] && printf '%s\n' "$access_token"
}

queue_asset_check_exchange_mailbox_exists() {
    local token="$1" upn="$2"; shift 2 || true
    local access_token timeout
    timeout="$(_queue_asset_exchange_param timeout "$@" || echo "$_EXCHANGE_TIMEOUT")"
    access_token="$(_queue_asset_exchange_get_token "$@")"
    if ! command -v curl >/dev/null 2>&1; then
        echo "asset_check_blocked: exchange:mailbox_exists requires curl"
        return 1
    fi
    if [[ -z "$access_token" || -z "$upn" ]]; then
        echo "asset_check_blocked: exchange:mailbox_exists requires target=user@domain and access_token=/env_file=/env_key="
        return 1
    fi
    if timeout "$timeout" curl -fsS -H "Authorization: Bearer $access_token" "https://graph.microsoft.com/v1.0/users/$upn/mailFolders/Inbox" >/dev/null 2>&1; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: exchange:mailbox_exists mailbox not accessible: $upn"
    return 1
}

queue_asset_check_exchange_send_test_mail() {
    local token="$1" upn="$2"; shift 2 || true
    local access_token timeout subject body allow_send payload
    timeout="$(_queue_asset_exchange_param timeout "$@" || echo "$_EXCHANGE_TIMEOUT")"
    access_token="$(_queue_asset_exchange_get_token "$@")"
    subject="$(_queue_asset_exchange_param subject "$@" || echo "queuebash test mail")"
    body="$(_queue_asset_exchange_param body "$@" || echo "This is a queuebash connectivity test.")"
    allow_send="$(_queue_asset_exchange_param allow_send "$@" || echo "0")"
    if [[ "$allow_send" != "1" ]]; then
        echo "asset_check_blocked: exchange:send_test_mail requires explicit allow_send=1 because it sends mail"
        return 1
    fi
    if ! command -v curl >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1; then
        echo "asset_check_blocked: exchange:send_test_mail requires curl and python3"
        return 1
    fi
    if [[ -z "$access_token" || -z "$upn" ]]; then
        echo "asset_check_blocked: exchange:send_test_mail requires target=user@domain and access_token=/env_file=/env_key="
        return 1
    fi
    payload="$(QB_SUBJECT="$subject" QB_BODY="$body" QB_TO="$upn" python3 - <<'PY'
import json, os
print(json.dumps({"message":{"subject":os.environ.get("QB_SUBJECT", "queuebash test mail"),"body":{"contentType":"Text","content":os.environ.get("QB_BODY", "This is a queuebash connectivity test.")},"toRecipients":[{"emailAddress":{"address":os.environ.get("QB_TO", "")}}]},"saveToSentItems":False}))
PY
)"
    if timeout "$timeout" curl -fsS -X POST -H "Authorization: Bearer $access_token" -H "Content-Type: application/json" -d "$payload" "https://graph.microsoft.com/v1.0/users/$upn/sendMail" >/dev/null 2>&1; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: exchange:send_test_mail failed for $upn"
    return 1
}
