#!/usr/bin/env bash
# bashqueues Microsoft Entra ID / Azure AD asset checks

_ENTRA_TIMEOUT="${ENTRA_TIMEOUT:-10}"

queue_asset_facilities() {
    cat <<'FACILITIES'
entra:token_valid	Validates an Entra JWT access token through the crypto:jwt helper when available
entra:graph_scope	Validates Microsoft Graph access using a supplied bearer token
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
entra:token_valid	target=/path/to/access.jwt	params=jwks_url=... issuer=... audience=... timeout=10	example=queue_class_shared_asset entra token_valid /run/queuebash/entra.jwt audience=https://graph.microsoft.com	notes=Delegates to crypto:jwt if that helper is loaded; otherwise fails closed.
entra:graph_scope	target=scope-label	params=access_token=...|env_file=/path/env env_key=GRAPH_TOKEN timeout=10 endpoint=/v1.0/me	example=queue_class_shared_asset entra graph_scope User.Read env_file=/run/queuebash/graph.env env_key=GRAPH_TOKEN	notes=Performs a minimal Graph probe. The target is descriptive; token scopes are enforced by Graph.
EOF_HINTS
}

_queue_asset_entra_param() { queue_asset_param "$@"; }

_queue_asset_entra_get_token() {
    local access_token env_file env_key
    access_token="$(_queue_asset_entra_param access_token "$@" || true)"
    env_file="$(_queue_asset_entra_param env_file "$@" || true)"
    env_key="$(_queue_asset_entra_param env_key "$@" || true)"
    if [[ -n "$env_file" && -r "$env_file" && -n "$env_key" ]]; then
        access_token="$(grep -E "^${env_key}=" "$env_file" | head -n1 | cut -d= -f2- | sed 's/^"//; s/"$//')"
    fi
    [[ -n "$access_token" ]] && printf '%s\n' "$access_token"
}

queue_asset_check_entra_token_valid() {
    local token="$1" jwt_file="$2"; shift 2 || true
    local jwks_url issuer audience timeout
    jwks_url="$(_queue_asset_entra_param jwks_url "$@" || echo "https://login.microsoftonline.com/common/discovery/v2.0/keys")"
    issuer="$(_queue_asset_entra_param issuer "$@" || true)"
    audience="$(_queue_asset_entra_param audience "$@" || true)"
    timeout="$(_queue_asset_entra_param timeout "$@" || echo "$_ENTRA_TIMEOUT")"

    if [[ ! -f "$jwt_file" ]]; then
        echo "asset_check_blocked: entra:token_valid target missing: $jwt_file"
        return 1
    fi
    if declare -F queue_asset_check_crypto_jwt >/dev/null 2>&1; then
        queue_asset_check_crypto_jwt "$token" "$jwt_file" "jwks_url=$jwks_url" "issuer=$issuer" "audience=$audience" "timeout=$timeout"
        return $?
    fi
    echo "asset_check_blocked: entra:token_valid requires crypto:jwt helper loaded"
    return 1
}

queue_asset_check_entra_graph_scope() {
    local token="$1" _scope="$2"; shift 2 || true
    local access_token timeout endpoint
    access_token="$(_queue_asset_entra_get_token "$@")"
    timeout="$(_queue_asset_entra_param timeout "$@" || echo "$_ENTRA_TIMEOUT")"
    endpoint="$(_queue_asset_entra_param endpoint "$@" || echo "/v1.0/me")"
    if ! command -v curl >/dev/null 2>&1; then
        echo "asset_check_blocked: entra:graph_scope requires curl"
        return 1
    fi
    if [[ -z "$access_token" ]]; then
        echo "asset_check_blocked: entra:graph_scope requires access_token= or env_file=/env_key="
        return 1
    fi
    if timeout "$timeout" curl -fsS -H "Authorization: Bearer $access_token" "https://graph.microsoft.com$endpoint" >/dev/null 2>&1; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: entra:graph_scope Graph API probe failed"
    return 1
}
