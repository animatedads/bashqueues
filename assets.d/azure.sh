#!/usr/bin/env bash
# bashqueues Azure Resource Manager asset checks

_AZURE_TIMEOUT="${AZURE_TIMEOUT:-10}"

queue_asset_facilities() {
    cat <<'FACILITIES'
azure:resource_exists	Validates that an Azure resource exists through ARM
azure:vm_powerstate	Validates Azure VM power state through ARM instanceView
azure:storage_account_access	Validates access to an Azure Blob storage account using a SAS token
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
azure:resource_exists	target=/subscriptions/.../resourceGroups/.../providers/...	params=access_token=...|env_file=/path/env env_key=AZURE_TOKEN timeout=10 api_version=2021-04-01	example=queue_class_shared_asset azure resource_exists /subscriptions/... env_file=/run/queuebash/azure.env env_key=AZURE_TOKEN	notes=Calls management.azure.com for the supplied resource ID.
azure:vm_powerstate	target=/subscriptions/.../providers/Microsoft.Compute/virtualMachines/name	params=expected=running access_token=...|env_file=/path/env env_key=AZURE_TOKEN timeout=10	example=queue_class_shared_asset azure vm_powerstate /subscriptions/.../virtualMachines/vm01 expected=running env_file=/run/queuebash/azure.env env_key=AZURE_TOKEN	notes=Requires curl and jq.
azure:storage_account_access	target=accountname	params=sas=... timeout=10	example=queue_class_shared_asset azure storage_account_access mystorage sas=$AZURE_STORAGE_SAS	notes=Lists blob service root using the supplied SAS.
EOF_HINTS
}

_queue_asset_azure_param() { queue_asset_param "$@"; }
_queue_asset_azure_get_token() {
    local access_token env_file env_key
    access_token="$(_queue_asset_azure_param access_token "$@" || true)"
    env_file="$(_queue_asset_azure_param env_file "$@" || true)"
    env_key="$(_queue_asset_azure_param env_key "$@" || true)"
    if [[ -n "$env_file" && -r "$env_file" && -n "$env_key" ]]; then
        access_token="$(grep -E "^${env_key}=" "$env_file" | head -n1 | cut -d= -f2- | sed 's/^"//; s/"$//')"
    fi
    [[ -n "$access_token" ]] && printf '%s\n' "$access_token"
}

queue_asset_check_azure_resource_exists() {
    local token="$1" resource_id="$2"; shift 2 || true
    local access_token timeout api_version
    timeout="$(_queue_asset_azure_param timeout "$@" || echo "$_AZURE_TIMEOUT")"
    api_version="$(_queue_asset_azure_param api_version "$@" || echo "2021-04-01")"
    access_token="$(_queue_asset_azure_get_token "$@")"
    if ! command -v curl >/dev/null 2>&1; then
        echo "asset_check_blocked: azure:resource_exists requires curl"
        return 1
    fi
    if [[ -z "$access_token" || -z "$resource_id" ]]; then
        echo "asset_check_blocked: azure:resource_exists requires target=/subscriptions/... and access_token=/env_file=/env_key="
        return 1
    fi
    if timeout "$timeout" curl -fsS -H "Authorization: Bearer $access_token" "https://management.azure.com$resource_id?api-version=$api_version" >/dev/null 2>&1; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: azure:resource_exists not found or inaccessible: $resource_id"
    return 1
}

queue_asset_check_azure_vm_powerstate() {
    local token="$1" resource_id="$2"; shift 2 || true
    local access_token timeout expected state
    timeout="$(_queue_asset_azure_param timeout "$@" || echo "$_AZURE_TIMEOUT")"
    expected="$(_queue_asset_azure_param expected "$@" || echo "running")"
    access_token="$(_queue_asset_azure_get_token "$@")"
    if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        echo "asset_check_blocked: azure:vm_powerstate requires curl and jq"
        return 1
    fi
    if [[ -z "$access_token" || -z "$resource_id" ]]; then
        echo "asset_check_blocked: azure:vm_powerstate requires target=VM resourceId and access_token=/env_file=/env_key="
        return 1
    fi
    state="$(timeout "$timeout" curl -fsS -H "Authorization: Bearer $access_token" "https://management.azure.com$resource_id/instanceView?api-version=2021-11-01" 2>/dev/null | jq -r '.statuses[]?.code | select(startswith("PowerState/")) | split("/")[-1]' 2>/dev/null || echo "")"
    if [[ "$state" == "$expected" ]]; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: azure:vm_powerstate expected=$expected got=${state:-unknown}"
    return 1
}

queue_asset_check_azure_storage_account_access() {
    local token="$1" account_name="$2"; shift 2 || true
    local sas timeout
    timeout="$(_queue_asset_azure_param timeout "$@" || echo "$_AZURE_TIMEOUT")"
    sas="$(_queue_asset_azure_param sas "$@" || true)"
    if ! command -v curl >/dev/null 2>&1; then
        echo "asset_check_blocked: azure:storage_account_access requires curl"
        return 1
    fi
    if [[ -z "$account_name" || -z "$sas" ]]; then
        echo "asset_check_blocked: azure:storage_account_access requires target=account_name and sas="
        return 1
    fi
    if timeout "$timeout" curl -fsS "https://$account_name.blob.core.windows.net/?comp=list&$sas" >/dev/null 2>&1; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: azure:storage_account_access failed for $account_name"
    return 1
}
