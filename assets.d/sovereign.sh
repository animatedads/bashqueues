#!/usr/bin/env bash
# bashqueues asset plugin: sovereign
# Data sovereignty / legal-framework region gates for multi-cloud workers.

queue_asset_facilities() {
    cat <<'FACILITIES'
sovereign:framework_allowed	Ensures the worker cloud region is permitted by a named legal framework
sovereign:region_in	Ensures the worker cloud region appears in an explicit comma-separated allow-list
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
sovereign:framework_allowed	target=legal framework name, e.g. GDPR|HIPAA|ITAR|UK_DPA	params=region=REGION policy_file=/path/to/legal_framework.env	example=queue_class_shared_asset sovereign framework_allowed "GDPR"	notes=Loads LEGAL_FRAMEWORK_<NAME>_REGIONS from legal-framework policy and compares against QUEUEBASH_CLOUD_REGION unless region= is supplied.
sovereign:region_in	target=comma-separated region allow-list	params=region=REGION	example=queue_class_shared_asset sovereign region_in "eu-west-2,europe-west2,uksouth"	notes=Direct allow-list check without a named legal framework.
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

_queue_asset_sovereign_policy_candidates() {
    local plugin_dir repo_root qroot explicit
    explicit="$(queue_asset_param policy_file "$@" || true)"
    [[ -n "$explicit" ]] && printf '%s\n' "$explicit"
    plugin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
    repo_root="$(cd "$plugin_dir/.." >/dev/null 2>&1 && pwd -P)"
    qroot="${QUEUEBASH_ROOT:-${HOME:-}/.queuebash}"
    printf '%s\n' \
        "/etc/bashqueues/policies.d/legal_framework.env" \
        "/etc/bashqueues/policies.d/legal-framework/default.env" \
        "$qroot/policies.d/legal_framework.env" \
        "$qroot/policies.d/legal-framework/default.env" \
        "$repo_root/policies.d/legal_framework.env" \
        "$repo_root/policies.d/legal-framework/default.env"
}

_queue_asset_sovereign_load_policy() {
    local f loaded=1
    while IFS= read -r f; do
        [[ -n "$f" && -r "$f" ]] || continue
        # Legal framework files are trusted local policy data and follow the
        # same KEY="value" convention as other bashqueues policy files.
        # shellcheck disable=SC1090
        source "$f"
        loaded=0
    done < <(_queue_asset_sovereign_policy_candidates "$@")
    return "$loaded"
}

_queue_asset_sovereign_norm_framework() {
    printf '%s' "${1:-}" | tr '[:lower:]-' '[:upper:]_' | sed 's/[^A-Z0-9_]/_/g; s/^_\+//; s/_\+$//'
}

_queue_asset_sovereign_csv_has() {
    local list="${1:-}" needle="${2:-}" item
    list="${list//[[:space:]]/}"
    IFS=',' read -r -a _qb_sovereign_items <<< "$list"
    for item in "${_qb_sovereign_items[@]}"; do
        [[ -n "$item" ]] || continue
        [[ "$item" == "$needle" || "$item" == "*" ]] && return 0
    done
    return 1
}

_queue_asset_sovereign_region() {
    local region
    region="$(queue_asset_param region "$@" || true)"
    printf '%s\n' "${region:-${QUEUEBASH_CLOUD_REGION:-unknown}}"
}

queue_asset_check_sovereign_framework_allowed() {
    local token="$1" framework="$2"; shift 2 || true
    local key allowed region

    [[ -n "$framework" ]] || { echo "asset_check_blocked: sovereign:framework_allowed framework_required"; return 1; }
    _queue_asset_sovereign_load_policy "$@" || { echo "asset_check_blocked: sovereign:framework_allowed missing_legal_policy"; return 1; }

    key="LEGAL_FRAMEWORK_$(_queue_asset_sovereign_norm_framework "$framework")_REGIONS"
    allowed="${!key:-}"
    [[ -n "$allowed" ]] || { echo "asset_check_blocked: sovereign:framework_allowed unknown_framework=$framework"; return 1; }

    region="$(_queue_asset_sovereign_region "$@")"
    [[ -n "$region" && "$region" != "unknown" ]] || { echo "asset_check_blocked: sovereign:framework_allowed cloud_region_unknown"; return 1; }

    if _queue_asset_sovereign_csv_has "$allowed" "$region"; then
        echo "asset_check_ok: $token"
        return 0
    fi

    echo "asset_check_blocked: sovereign:framework_allowed framework=$framework region=$region allowed=$allowed"
    return 1
}

queue_asset_check_sovereign_region_in() {
    local token="$1" allowed="$2"; shift 2 || true
    local region
    [[ -n "$allowed" ]] || { echo "asset_check_blocked: sovereign:region_in allow_list_required"; return 1; }
    region="$(_queue_asset_sovereign_region "$@")"
    [[ -n "$region" && "$region" != "unknown" ]] || { echo "asset_check_blocked: sovereign:region_in cloud_region_unknown"; return 1; }
    if _queue_asset_sovereign_csv_has "$allowed" "$region"; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: sovereign:region_in region=$region allowed=$allowed"
    return 1
}
