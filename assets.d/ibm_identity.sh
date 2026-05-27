#!/usr/bin/env bash
# bashqueues asset plugin: ibm_identity
# IBM Cloud identity and region/sovereignty preflight gates.
#
# This asset is intentionally narrow. It validates local IBM Cloud CLI identity
# and configured region policy. It does not implement IBM FinOps scraping,
# Activity Tracker/Cloud Logs reporters, HPCS key-provider operations, Watson,
# or Satellite worker identity.

_IBM_TIMEOUT="${IBM_TIMEOUT:-10}"

queue_asset_facilities() {
    cat <<'FACILITIES'
ibm_identity:auth_active	Validates that ibmcloud CLI is installed and has an active account/target session
ibm_identity:target_region_allowed	Checks QUEUEBASH_IBM_REGION or QUEUEBASH_CLOUD_REGION against an IBM framework region mapping
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
ibm_identity:auth_active	target=account id or _	params=timeout=10 require_auth=1	example=queue_class_shared_asset ibm_identity auth_active _	notes=Runs ibmcloud target. Does not print credentials or tokens.
ibm_identity:target_region_allowed	target=GDPR|UK_DPA|FINREG|LEGAL|IBM_ALL	params=region=REGION allow=csv	example=queue_class_shared_asset ibm_identity target_region_allowed GDPR region=eu-gb	notes=Uses region=, QUEUEBASH_IBM_REGION, or QUEUEBASH_CLOUD_REGION. No network call is needed when region is configured.
EOF_HINTS
}

queue_asset_param() {
    local key="$1" p
    shift || true
    for p in "$@"; do
        case "$p" in
            "$key="*) printf '%s\n' "${p#*=}"; return 0 ;;
        esac
    done
    return 1
}

_queue_asset_ibm_norm() {
    printf '%s' "${1:-}" | tr '[:lower:]-' '[:upper:]_' | sed 's/[^A-Z0-9_]/_/g; s/^_\+//; s/_\+$//'
}

_queue_asset_ibm_csv_has() {
    local list="${1:-}" needle="${2:-}" item
    list="${list//[[:space:]]/}"
    IFS=',' read -r -a _qb_ibm_items <<< "$list"
    for item in "${_qb_ibm_items[@]}"; do
        [[ -n "$item" ]] || continue
        [[ "$item" == "$needle" || "$item" == "*" ]] && return 0
    done
    return 1
}

_queue_asset_ibm_region() {
    local region
    region="$(queue_asset_param region "$@" || true)"
    printf '%s\n' "${region:-${QUEUEBASH_IBM_REGION:-${QUEUEBASH_CLOUD_REGION:-unknown}}}"
}

_queue_asset_ibm_allowed_regions_for_framework() {
    local framework
    framework="$(_queue_asset_ibm_norm "${1:-IBM_ALL}")"
    case "$framework" in
        GDPR|EU|EEA)
            printf '%s\n' "eu-de,eu-gb,eu-es" ;;
        UK_DPA|UK)
            printf '%s\n' "eu-gb" ;;
        FINREG|FINANCIAL_SERVICES|IBM_FINANCIAL_SERVICES)
            # This is a governance allow-list template, not an assertion that a
            # specific workload is IBM Cloud for Financial Services compliant.
            printf '%s\n' "us-south,us-east,ca-tor,eu-de,eu-gb,eu-es,au-syd,jp-tok,jp-osa,br-sao" ;;
        LEGAL|LEGAL_COMPLIANCE|IBM_ALL|ALL)
            printf '%s\n' "us-south,us-east,br-sao,ca-tor,eu-de,eu-gb,eu-es,au-syd,jp-osa,jp-tok" ;;
        *)
            return 1 ;;
    esac
}

queue_asset_check_ibm_identity_auth_active() {
    local token="$1" expect_account="$2"; shift 2 || true
    local timeout require_auth account target_out
    timeout="$(queue_asset_param timeout "$@" || echo "$_IBM_TIMEOUT")"
    require_auth="$(queue_asset_param require_auth "$@" || echo "${QUEUEBASH_IBM_AUTH_REQUIRED:-1}")"

    if [[ "$require_auth" == "0" || "${require_auth,,}" == "false" || "${require_auth,,}" == "no" ]]; then
        echo "asset_check_ok: $token"
        return 0
    fi

    if ! command -v ibmcloud >/dev/null 2>&1; then
        echo "asset_check_blocked: ibm_identity:auth_active tool_missing=ibmcloud"
        return 1
    fi

    target_out="$(timeout "$timeout" ibmcloud target 2>/dev/null || true)"
    [[ -n "$target_out" ]] || { echo "asset_check_blocked: ibm_identity:auth_active no_active_target"; return 1; }

    if [[ -n "$expect_account" && "$expect_account" != "_" ]]; then
        account="${QUEUEBASH_IBM_ACCOUNT_ID:-}"
        if [[ -z "$account" ]]; then
            account="$(printf '%s\n' "$target_out" | awk -F: 'tolower($1) ~ /account/ { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit }')"
        fi
        [[ "$account" == "$expect_account" ]] || {
            echo "asset_check_blocked: ibm_identity:auth_active account_mismatch expected=$expect_account got=${account:-unknown}"
            return 1
        }
    fi

    echo "asset_check_ok: $token"
    return 0
}

queue_asset_check_ibm_identity_target_region_allowed() {
    local token="$1" framework="$2"; shift 2 || true
    local region allowed override
    framework="${framework:-IBM_ALL}"
    region="$(_queue_asset_ibm_region "$@")"
    [[ -n "$region" && "$region" != "unknown" ]] || { echo "asset_check_blocked: ibm_identity:target_region_allowed region_unknown"; return 1; }

    override="$(queue_asset_param allow "$@" || true)"
    if [[ -n "$override" ]]; then
        allowed="$override"
    else
        allowed="$(_queue_asset_ibm_allowed_regions_for_framework "$framework" || true)"
    fi
    [[ -n "$allowed" ]] || { echo "asset_check_blocked: ibm_identity:target_region_allowed unknown_framework=$framework"; return 1; }

    if _queue_asset_ibm_csv_has "$allowed" "$region"; then
        echo "asset_check_ok: $token"
        return 0
    fi

    echo "asset_check_blocked: ibm_identity:target_region_allowed framework=$framework region=$region allowed=$allowed"
    return 1
}
