#!/usr/bin/env bash
# bashqueues asset plugin: finops
# Cost-control gates driven by local pricing/budget caches.

queue_asset_facilities() {
    cat <<'FACILITIES'
finops:spot_price_below	Blocks dispatch when cached spot/market price is above the requested threshold
finops:budget_remaining	Blocks dispatch unless a named budget cache reports at least the requested remaining amount
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
finops:spot_price_below	target=max price per hour	params=instance_type=TYPE region=REGION cache_file=/path timeout=5	example=queue_class_shared_asset finops spot_price_below "0.08" instance_type=m5.large	notes=Reads a local pricing cache. It does not call cloud APIs in the worker preflight path.
finops:budget_remaining	target=budget name	params=min_remaining=10 cache_file=/path	example=queue_class_shared_asset finops budget_remaining "gdpr-processing" min_remaining=25	notes=Reads a local budget cache containing either a plain number or KEY=value lines.
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

_queue_asset_finops_number() {
    [[ "${1:-}" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

_queue_asset_finops_le() {
    awk -v a="$1" -v b="$2" 'BEGIN { exit !(a+0 <= b+0) }'
}

_queue_asset_finops_ge() {
    awk -v a="$1" -v b="$2" 'BEGIN { exit !(a+0 >= b+0) }'
}

_queue_asset_finops_safe_token() {
    printf '%s' "${1:-unknown}" | sed 's#[^A-Za-z0-9_.-]#_#g'
}

queue_asset_check_finops_spot_price_below() {
    local token="$1" max_price="$2"; shift 2 || true
    local instance_type region cache_file current

    instance_type="$(queue_asset_param instance_type "$@" || true)"
    [[ -n "$instance_type" ]] || instance_type="${1:-${QUEUEBASH_CLOUD_INSTANCE_TYPE:-unknown}}"
    region="$(queue_asset_param region "$@" || true)"
    region="${region:-${QUEUEBASH_CLOUD_REGION:-unknown}}"
    cache_file="$(queue_asset_param cache_file "$@" || true)"
    [[ -n "$cache_file" ]] || cache_file="/var/tmp/queuebash_pricing_$(_queue_asset_finops_safe_token "$region")_$(_queue_asset_finops_safe_token "$instance_type").txt"

    _queue_asset_finops_number "$max_price" || { echo "asset_check_blocked: finops:spot_price_below invalid_max_price=$max_price"; return 1; }
    [[ -r "$cache_file" ]] || { echo "asset_check_blocked: finops:spot_price_below no_pricing_data cache=$cache_file"; return 1; }
    current="$(awk 'NF {print $1; exit}' "$cache_file" 2>/dev/null || true)"
    _queue_asset_finops_number "$current" || { echo "asset_check_blocked: finops:spot_price_below invalid_price cache=$cache_file"; return 1; }

    if _queue_asset_finops_le "$current" "$max_price"; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: finops:spot_price_below price=$current max=$max_price region=$region instance_type=$instance_type"
    return 1
}

queue_asset_check_finops_budget_remaining() {
    local token="$1" budget="$2"; shift 2 || true
    local min_remaining cache_file remaining
    min_remaining="$(queue_asset_param min_remaining "$@" || echo 0)"
    cache_file="$(queue_asset_param cache_file "$@" || true)"
    [[ -n "$cache_file" ]] || cache_file="/var/tmp/queuebash_budget_$(_queue_asset_finops_safe_token "$budget").txt"
    [[ -n "$budget" ]] || { echo "asset_check_blocked: finops:budget_remaining budget_required"; return 1; }
    _queue_asset_finops_number "$min_remaining" || { echo "asset_check_blocked: finops:budget_remaining invalid_min_remaining=$min_remaining"; return 1; }
    [[ -r "$cache_file" ]] || { echo "asset_check_blocked: finops:budget_remaining no_budget_data cache=$cache_file"; return 1; }
    remaining="$(awk -F= '/^remaining=/ {print $2; found=1; exit} !found && NF {print $1; exit}' "$cache_file" 2>/dev/null || true)"
    _queue_asset_finops_number "$remaining" || { echo "asset_check_blocked: finops:budget_remaining invalid_remaining cache=$cache_file"; return 1; }
    if _queue_asset_finops_ge "$remaining" "$min_remaining"; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: finops:budget_remaining budget=$budget remaining=$remaining min=$min_remaining"
    return 1
}
