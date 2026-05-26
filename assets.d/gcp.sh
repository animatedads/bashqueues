#!/usr/bin/env bash
# bashqueues asset plugin: gcp
# Google Cloud preflight gates.

_GCP_TIMEOUT="${GCP_TIMEOUT:-10}"

queue_asset_facilities() {
    cat <<'FACILITIES'
gcp:auth_active	Validates that gcloud can produce an active access token
gcp:project_active	Validates the active or requested gcloud project
gcp:region_allowed	Checks that the configured GCP region is in an allow-list
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
gcp:auth_active	target=account name or _	params=timeout=10	example=queue_class_shared_asset gcp auth_active _	notes=Runs gcloud auth print-access-token. Does not print the token.
gcp:project_active	target=project id	params=timeout=10	example=queue_class_shared_asset gcp project_active my-project	notes=Checks gcloud config project or projects describe.
gcp:region_allowed	target=comma-separated GCP regions	params=region=REGION	example=queue_class_shared_asset gcp region_allowed "europe-west2,europe-west3"	notes=Uses QUEUEBASH_CLOUD_REGION unless region= is provided.
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

_queue_asset_gcp_csv_has() {
    local list="${1:-}" needle="${2:-}" item
    list="${list//[[:space:]]/}"
    IFS=',' read -r -a _qb_gcp_items <<< "$list"
    for item in "${_qb_gcp_items[@]}"; do
        [[ "$item" == "$needle" || "$item" == "*" ]] && return 0
    done
    return 1
}

queue_asset_check_gcp_auth_active() {
    local token="$1" expect_account="$2"; shift 2 || true
    local timeout account
    timeout="$(queue_asset_param timeout "$@" || echo "$_GCP_TIMEOUT")"
    if ! command -v gcloud >/dev/null 2>&1; then
        echo "asset_check_blocked: gcp:auth_active tool_missing=gcloud"
        return 1
    fi
    timeout "$timeout" gcloud auth print-access-token >/dev/null 2>&1 || { echo "asset_check_blocked: gcp:auth_active no_valid_token"; return 1; }
    if [[ -n "$expect_account" && "$expect_account" != "_" ]]; then
        account="$(timeout "$timeout" gcloud config get-value core/account 2>/dev/null || true)"
        [[ "$account" == "$expect_account" ]] || { echo "asset_check_blocked: gcp:auth_active account_mismatch expected=$expect_account got=${account:-unknown}"; return 1; }
    fi
    echo "asset_check_ok: $token"
    return 0
}

queue_asset_check_gcp_project_active() {
    local token="$1" project="$2"; shift 2 || true
    local timeout active
    timeout="$(queue_asset_param timeout "$@" || echo "$_GCP_TIMEOUT")"
    [[ -n "$project" && "$project" != "_" ]] || { echo "asset_check_blocked: gcp:project_active project_required"; return 1; }
    if ! command -v gcloud >/dev/null 2>&1; then
        echo "asset_check_blocked: gcp:project_active tool_missing=gcloud"
        return 1
    fi
    active="$(timeout "$timeout" gcloud config get-value project 2>/dev/null || true)"
    if [[ "$active" == "$project" ]]; then
        echo "asset_check_ok: $token"
        return 0
    fi
    if timeout "$timeout" gcloud projects describe "$project" >/dev/null 2>&1; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: gcp:project_active project_not_accessible=$project active=${active:-unknown}"
    return 1
}

queue_asset_check_gcp_region_allowed() {
    local token="$1" allowed="$2"; shift 2 || true
    local region
    region="$(queue_asset_param region "$@" || true)"
    region="${region:-${QUEUEBASH_CLOUD_REGION:-unknown}}"
    [[ -n "$allowed" ]] || { echo "asset_check_blocked: gcp:region_allowed allow_list_required"; return 1; }
    [[ -n "$region" && "$region" != "unknown" ]] || { echo "asset_check_blocked: gcp:region_allowed cloud_region_unknown"; return 1; }
    if _queue_asset_gcp_csv_has "$allowed" "$region"; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: gcp:region_allowed region=$region allowed=$allowed"
    return 1
}
