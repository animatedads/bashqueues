#!/usr/bin/env bash
# bashqueues Azure Key Vault asset checks

_VAULT_TIMEOUT="${VAULT_TIMEOUT:-10}"

queue_asset_facilities() {
    cat <<'FACILITIES'
vault:secret_exists	Validates that a secret exists in Azure Key Vault
vault:secret_version	Validates that a specific secret version exists in Azure Key Vault
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
vault:secret_exists	target=secret_name	params=vault_uri=https://vault.vault.azure.net access_token=...|env_file=/path/env env_key=AZURE_TOKEN timeout=10	example=queue_class_shared_asset vault secret_exists db-password vault_uri=https://myvault.vault.azure.net env_file=/run/queuebash/azure.env env_key=AZURE_TOKEN	notes=Checks metadata/access; does not print secret values.
vault:secret_version	target=secret_name	params=version=... vault_uri=https://vault.vault.azure.net access_token=...|env_file=/path/env env_key=AZURE_TOKEN timeout=10	example=queue_class_shared_asset vault secret_version db-password version=abc123 vault_uri=https://myvault.vault.azure.net env_file=/run/queuebash/azure.env env_key=AZURE_TOKEN	notes=Checks the named version exists and is accessible.
EOF_HINTS
}

_queue_asset_vault_param() { queue_asset_param "$@"; }
_queue_asset_vault_get_token() {
    local access_token env_file env_key
    access_token="$(_queue_asset_vault_param access_token "$@" || true)"
    env_file="$(_queue_asset_vault_param env_file "$@" || true)"
    env_key="$(_queue_asset_vault_param env_key "$@" || true)"
    if [[ -n "$env_file" && -r "$env_file" && -n "$env_key" ]]; then
        access_token="$(grep -E "^${env_key}=" "$env_file" | head -n1 | cut -d= -f2- | sed 's/^"//; s/"$//')"
    fi
    [[ -n "$access_token" ]] && printf '%s\n' "$access_token"
}

queue_asset_check_vault_secret_exists() {
    local token="$1" secret_name="$2"; shift 2 || true
    local vault_uri access_token timeout
    vault_uri="$(_queue_asset_vault_param vault_uri "$@" || true)"
    timeout="$(_queue_asset_vault_param timeout "$@" || echo "$_VAULT_TIMEOUT")"
    access_token="$(_queue_asset_vault_get_token "$@")"
    if ! command -v curl >/dev/null 2>&1; then
        echo "asset_check_blocked: vault:secret_exists requires curl"
        return 1
    fi
    if [[ -z "$vault_uri" || -z "$secret_name" || -z "$access_token" ]]; then
        echo "asset_check_blocked: vault:secret_exists requires vault_uri= target=secret_name and access_token=/env_file=/env_key="
        return 1
    fi
    if timeout "$timeout" curl -fsS -H "Authorization: Bearer $access_token" "$vault_uri/secrets/$secret_name?api-version=7.3" >/dev/null 2>&1; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: vault:secret_exists missing or inaccessible: $secret_name"
    return 1
}

queue_asset_check_vault_secret_version() {
    local token="$1" secret_name="$2"; shift 2 || true
    local vault_uri version access_token timeout
    vault_uri="$(_queue_asset_vault_param vault_uri "$@" || true)"
    version="$(_queue_asset_vault_param version "$@" || true)"
    timeout="$(_queue_asset_vault_param timeout "$@" || echo "$_VAULT_TIMEOUT")"
    access_token="$(_queue_asset_vault_get_token "$@")"
    if ! command -v curl >/dev/null 2>&1; then
        echo "asset_check_blocked: vault:secret_version requires curl"
        return 1
    fi
    if [[ -z "$vault_uri" || -z "$secret_name" || -z "$version" || -z "$access_token" ]]; then
        echo "asset_check_blocked: vault:secret_version requires vault_uri= target=secret_name version= and access_token=/env_file=/env_key="
        return 1
    fi
    if timeout "$timeout" curl -fsS -H "Authorization: Bearer $access_token" "$vault_uri/secrets/$secret_name/$version?api-version=7.3" >/dev/null 2>&1; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: vault:secret_version missing or inaccessible: $secret_name@$version"
    return 1
}
