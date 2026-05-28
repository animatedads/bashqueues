#!/usr/bin/env bash
# bashqueues asset plugin: legal
# Registry-backed legal compliance gates for retention, holds, erasure and jurisdiction.

queue_asset_facilities() {
    cat <<'FACILITIES'
legal:retention_respected	Checks a dataset/case legal registry before destructive/export/archive work is allowed
legal:jurisdiction_allowed	Checks the worker/class jurisdiction is compatible with the dataset/case registry scope
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
legal:retention_respected	target=dataset-or-case-id	params=registry_file=/path effect=readonly|export|destructive|delete|archive now=YYYY-MM-DD allow_user_registry=1	example=queue_class_shared_asset legal retention_respected dataset:case-123 effect=destructive registry_file=/etc/queuebash/legal_registry.tsv	notes=Registry-backed; does not trust user-supplied JOB_LEGAL_CLASS as authority.
legal:jurisdiction_allowed	target=dataset-or-case-id	params=registry_file=/path worker_jurisdiction=UK_DPA allow_user_registry=1	example=queue_class_shared_asset legal jurisdiction_allowed dataset:case-123 worker_jurisdiction=UK_DPA	notes=Allows empty/*/any scopes; otherwise worker jurisdiction must match one listed registry scope.
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

_queue_asset_legal_default_registry() {
    if [[ -n "${QUEUEBASH_LEGAL_REGISTRY:-}" ]]; then
        printf '%s\n' "$QUEUEBASH_LEGAL_REGISTRY"
    elif [[ -n "${QUEUEBASH_ROOT:-}" && -f "$QUEUEBASH_ROOT/policies.d/legal_registry.tsv" ]]; then
        printf '%s\n' "$QUEUEBASH_ROOT/policies.d/legal_registry.tsv"
    elif [[ -f /etc/queuebash/legal_registry.tsv ]]; then
        printf '%s\n' /etc/queuebash/legal_registry.tsv
    elif [[ -f /etc/queuebash/policies.d/legal-registry/default.tsv ]]; then
        printf '%s\n' /etc/queuebash/policies.d/legal-registry/default.tsv
    else
        printf '%s\n' /etc/queuebash/legal_registry.tsv
    fi
}

_queue_asset_legal_under_user_root() {
    local path="$1" root="${QUEUEBASH_ROOT:-}"
    [[ -n "$root" ]] || return 1
    case "$path" in
        "$root"|"$root"/*) return 0 ;;
        *) return 1 ;;
    esac
}

_queue_asset_legal_registry_allowed() {
    local file="$1" allow_user="${2:-0}"
    [[ -n "$file" ]] || { echo "asset_check_blocked: legal registry_required"; return 1; }
    [[ -r "$file" ]] || { echo "asset_check_blocked: legal registry_unreadable file=$file"; return 1; }
    if _queue_asset_legal_under_user_root "$file" && [[ "$allow_user" != "1" && "$allow_user" != "true" && "$allow_user" != "yes" ]]; then
        echo "asset_check_blocked: legal registry_under_queue_root_requires_allow_user_registry file=$file"
        return 1
    fi
    return 0
}

_queue_asset_legal_find_record() {
    local wanted="$1" file="$2"
    awk -v want="$wanted" '
        BEGIN { FS="[\t ]+" }
        /^[[:space:]]*$/ { next }
        /^[[:space:]]*#/ { next }
        $1 == want { print; found=1; exit }
        END { if (!found) exit 1 }
    ' "$file" 2>/dev/null
}

_queue_asset_legal_field() {
    local rec="$1" pos="$2"
    awk -v n="$pos" 'BEGIN { FS="[\t ]+" } { print $n }' <<< "$rec"
}

_queue_asset_legal_effect_is_destructive() {
    case "${1,,}" in
        destructive|delete|remove|erase|archive|prune|purge|write|migration|migrate) return 0 ;;
        *) return 1 ;;
    esac
}

_queue_asset_legal_effect_is_export() {
    case "${1,,}" in
        export|extract|egress|transfer) return 0 ;;
        *) return 1 ;;
    esac
}

_queue_asset_legal_date_epoch() {
    local d="$1"
    [[ -n "$d" && "$d" != "-" && "$d" != "none" ]] || return 1
    date -d "$d" +%s 2>/dev/null
}

_queue_asset_legal_today_epoch() {
    local now="$1"
    if [[ -n "$now" ]]; then
        _queue_asset_legal_date_epoch "$now" && return 0
    fi
    date -u +%s 2>/dev/null || date +%s
}

_queue_asset_legal_scope_matches() {
    local worker="${1:-}" scopes="${2:-}"
    local s
    [[ -z "$scopes" || "$scopes" == "-" || "$scopes" == "*" || "${scopes,,}" == "any" ]] && return 0
    IFS=',' read -r -a parts <<< "$scopes"
    for s in "${parts[@]}"; do
        s="${s// /}"
        [[ -z "$s" ]] && continue
        [[ "${s,,}" == "${worker,,}" ]] && return 0
    done
    return 1
}

# Registry TSV format:
#   id  legal_class  retention_until  jurisdiction_scope  destructive_allowed  export_allowed
# Example:
#   dataset:case-123 LITIGATION_HOLD 2031-01-01 UK_DPA 0 1
queue_asset_check_legal_retention_respected() {
    local token="$1" target="$2"; shift 2 || true
    local registry allow_user effect now rec legal_class retention_until jurisdiction destructive_allowed export_allowed
    local now_epoch retention_epoch

    registry="$(queue_asset_param registry_file "$@" || true)"
    registry="${registry:-$(queue_asset_param registry "$@" || true)}"
    registry="${registry:-$(_queue_asset_legal_default_registry)}"
    allow_user="$(queue_asset_param allow_user_registry "$@" || echo 0)"
    effect="$(queue_asset_param effect "$@" || true)"
    effect="${effect:-${QUEUEBASH_CLASS_EFFECT:-${CLASS_EFFECT:-readonly}}}"
    now="$(queue_asset_param now "$@" || true)"

    [[ -n "$target" ]] || { echo "asset_check_blocked: legal:retention_respected target_required"; return 1; }
    _queue_asset_legal_registry_allowed "$registry" "$allow_user" || return 1
    rec="$(_queue_asset_legal_find_record "$target" "$registry" || true)"
    [[ -n "$rec" ]] || { echo "asset_check_blocked: legal:retention_respected no_registry_record target=$target registry=$registry"; return 1; }

    legal_class="$(_queue_asset_legal_field "$rec" 2)"
    retention_until="$(_queue_asset_legal_field "$rec" 3)"
    jurisdiction="$(_queue_asset_legal_field "$rec" 4)"
    destructive_allowed="$(_queue_asset_legal_field "$rec" 5)"
    export_allowed="$(_queue_asset_legal_field "$rec" 6)"

    case "${legal_class^^}" in
        LITIGATION_HOLD|RETENTION_LOCKED)
            if _queue_asset_legal_effect_is_destructive "$effect" && [[ "$destructive_allowed" != "1" && "${destructive_allowed,,}" != "true" && "${destructive_allowed,,}" != "yes" ]]; then
                echo "asset_check_blocked: legal:retention_respected target=$target legal_class=$legal_class effect=$effect destructive_denied"
                return 1
            fi
            ;;
        ERASURE_REQUESTED)
            now_epoch="$(_queue_asset_legal_today_epoch "$now" || echo 0)"
            retention_epoch="$(_queue_asset_legal_date_epoch "$retention_until" || echo 0)"
            if [[ "$retention_epoch" =~ ^[0-9]+$ && "$retention_epoch" -gt "$now_epoch" ]] && _queue_asset_legal_effect_is_destructive "$effect"; then
                echo "asset_check_blocked: legal:retention_respected target=$target erasure_conflicts_with_retention_until=$retention_until effect=$effect"
                return 1
            fi
            ;;
    esac

    if _queue_asset_legal_effect_is_export "$effect" && [[ "$export_allowed" == "0" || "${export_allowed,,}" == "false" || "${export_allowed,,}" == "no" ]]; then
        echo "asset_check_blocked: legal:retention_respected target=$target export_denied legal_class=$legal_class"
        return 1
    fi

    echo "asset_check_ok: $token target=$target legal_class=${legal_class:-none} effect=$effect jurisdiction=${jurisdiction:-none}"
    return 0
}

queue_asset_check_legal_jurisdiction_allowed() {
    local token="$1" target="$2"; shift 2 || true
    local registry allow_user worker rec scope

    registry="$(queue_asset_param registry_file "$@" || true)"
    registry="${registry:-$(queue_asset_param registry "$@" || true)}"
    registry="${registry:-$(_queue_asset_legal_default_registry)}"
    allow_user="$(queue_asset_param allow_user_registry "$@" || echo 0)"
    worker="$(queue_asset_param worker_jurisdiction "$@" || true)"
    worker="${worker:-${QUEUEBASH_JURISDICTION:-${QUEUEBASH_WORKER_JURISDICTION:-unknown}}}"

    [[ -n "$target" ]] || { echo "asset_check_blocked: legal:jurisdiction_allowed target_required"; return 1; }
    _queue_asset_legal_registry_allowed "$registry" "$allow_user" || return 1
    rec="$(_queue_asset_legal_find_record "$target" "$registry" || true)"
    [[ -n "$rec" ]] || { echo "asset_check_blocked: legal:jurisdiction_allowed no_registry_record target=$target registry=$registry"; return 1; }
    scope="$(_queue_asset_legal_field "$rec" 4)"

    if _queue_asset_legal_scope_matches "$worker" "$scope"; then
        echo "asset_check_ok: $token target=$target worker_jurisdiction=$worker scope=${scope:-any}"
        return 0
    fi

    echo "asset_check_blocked: legal:jurisdiction_allowed target=$target worker_jurisdiction=$worker required_scope=$scope"
    return 1
}
