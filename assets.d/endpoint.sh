#!/usr/bin/env bash
# bashqueues asset plugin: endpoint
# Endpoint sovereignty gates for jobs that submit/connect to external services.

queue_asset_facilities() {
    cat <<'FACILITIES'
endpoint:jurisdiction_allowed	Ensures a named endpoint maps to a region permitted by a legal framework
endpoint:region_allowed	Ensures a named endpoint maps to one of an explicit region allow-list
endpoint:command_jurisdiction_allowed	Scans the queued command for endpoints and requires each mapped region to satisfy a legal framework
endpoint:command_region_allowed	Scans the queued command for endpoints and requires each mapped region to appear in an explicit allow-list
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
endpoint:jurisdiction_allowed	target=URL, host, host:port, or IP	params=framework=UK_DPA|GDPR|HIPAA target_region=REGION endpoint_policy_file=/path resolve_dns=1 allow_private_unknown=0	example=queue_class_shared_asset endpoint jurisdiction_allowed "https://api.example.uk/submit" framework=UK_DPA	notes=Fails closed unless the endpoint maps to a region allowed by LEGAL_FRAMEWORK_<framework>_REGIONS. Mapping comes from endpoint-jurisdiction policy, explicit target_region=, or optional DNS/IP mapping.
endpoint:region_allowed	target=URL, host, host:port, or IP	params=regions=eu-west-2,uksouth target_region=REGION endpoint_policy_file=/path resolve_dns=1 allow_private_unknown=0	example=queue_class_shared_asset endpoint region_allowed "api.example.uk:443" regions=eu-west-2,uksouth	notes=Direct endpoint region allow-list without a named legal framework.
endpoint:command_jurisdiction_allowed	target=legal framework name	params=resolve_dns=1 allow_empty=1 allow_private_unknown=0 endpoint_policy_file=/path	example=CLASS_POLICY_MANDATORY_ASSETS=$'endpoint\tcommand_jurisdiction_allowed\tUK_DPA'	notes=Extracts http(s) URLs and host:port tokens from the queued command and checks every endpoint against the framework.
endpoint:command_region_allowed	target=comma-separated region allow-list	params=resolve_dns=1 allow_empty=1 allow_private_unknown=0 endpoint_policy_file=/path	example=queue_class_shared_asset endpoint command_region_allowed "eu-west-2,uksouth" allow_empty=1	notes=Command-line endpoint scan against an explicit region allow-list.
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

_queue_endpoint_policy_candidates() {
    local explicit plugin_dir repo_root qroot
    explicit="$(queue_asset_param endpoint_policy_file "$@" || true)"
    [[ -n "$explicit" ]] && printf '%s\n' "$explicit"
    plugin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
    repo_root="$(cd "$plugin_dir/.." >/dev/null 2>&1 && pwd -P)"
    qroot="${QUEUEBASH_ROOT:-${HOME:-}/.queuebash}"
    printf '%s\n' \
        "/etc/bashqueues/policies.d/endpoint-jurisdiction/default.env" \
        "/etc/bashqueues/policies.d/endpoint_jurisdiction.env" \
        "/etc/bashqueues/policies.d/legal-framework/default.env" \
        "/etc/bashqueues/policies.d/legal_framework.env" \
        "$qroot/policies.d/endpoint-jurisdiction/default.env" \
        "$qroot/policies.d/endpoint_jurisdiction.env" \
        "$qroot/policies.d/legal-framework/default.env" \
        "$qroot/policies.d/legal_framework.env" \
        "$repo_root/policies.d/endpoint-jurisdiction/default.env" \
        "$repo_root/policies.d/endpoint_jurisdiction.env" \
        "$repo_root/policies.d/legal-framework/default.env" \
        "$repo_root/policies.d/legal_framework.env"
}

_queue_endpoint_load_policy() {
    local f loaded=1
    while IFS= read -r f; do
        [[ -n "$f" && -r "$f" ]] || continue
        # Endpoint/legal maps are trusted local policy data.
        # shellcheck disable=SC1090
        source "$f"
        loaded=0
    done < <(_queue_endpoint_policy_candidates "$@")
    return "$loaded"
}

_queue_endpoint_norm_key() {
    printf '%s' "${1:-}" | tr '[:lower:]-.' '[:upper:]__' | sed 's/[^A-Z0-9_]/_/g; s/^_\+//; s/_\+$//'
}

_queue_endpoint_norm_framework() {
    printf '%s' "${1:-}" | tr '[:lower:]-' '[:upper:]_' | sed 's/[^A-Z0-9_]/_/g; s/^_\+//; s/_\+$//'
}

_queue_endpoint_csv_has() {
    local list="${1:-}" needle="${2:-}" item
    list="${list//[[:space:]]/}"
    IFS=',' read -r -a _qb_endpoint_items <<< "$list"
    for item in "${_qb_endpoint_items[@]}"; do
        [[ -n "$item" ]] || continue
        [[ "$item" == "$needle" || "$item" == "*" ]] && return 0
    done
    return 1
}

_queue_endpoint_bool() {
    case "${1:-}" in 1|yes|true|on|Y|y) return 0 ;; *) return 1 ;; esac
}

_queue_endpoint_host_from_target() {
    local raw="${1:-}" host
    raw="${raw#\"}"; raw="${raw%\"}"; raw="${raw#\'}"; raw="${raw%\'}"
    case "$raw" in
        http://*|https://*)
            host="${raw#*://}"
            host="${host%%/*}"
            host="${host%%\?*}"
            host="${host%%#*}"
            ;;
        *)
            host="$raw"
            host="${host%%/*}"
            ;;
    esac
    host="${host#[}"
    host="${host%]}"
    # Strip :port for ordinary host:port / IPv4:port, but avoid mangling IPv6.
    if [[ "$host" != *:*:* && "$host" == *:* ]]; then
        host="${host%:*}"
    fi
    printf '%s\n' "$host"
}

_queue_endpoint_is_ipv4() {
    [[ "${1:-}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    local IFS=. a b c d
    read -r a b c d <<< "$1"
    (( a <= 255 && b <= 255 && c <= 255 && d <= 255 ))
}

_queue_endpoint_ipv4_to_int() {
    local IFS=. a b c d
    _queue_endpoint_is_ipv4 "$1" || return 1
    read -r a b c d <<< "$1"
    printf '%u\n' $(( (10#$a << 24) + (10#$b << 16) + (10#$c << 8) + 10#$d ))
}

_queue_endpoint_ipv4_private() {
    local ip="$1" IFS=. a b c d
    _queue_endpoint_is_ipv4 "$ip" || return 1
    read -r a b c d <<< "$ip"
    (( a == 10 )) && return 0
    (( a == 172 && b >= 16 && b <= 31 )) && return 0
    (( a == 192 && b == 168 )) && return 0
    (( a == 127 )) && return 0
    (( a == 169 && b == 254 )) && return 0
    return 1
}

_queue_endpoint_ip_in_cidr() {
    local ip="$1" cidr="$2" base bits ip_i base_i mask
    base="${cidr%/*}"; bits="${cidr#*/}"
    [[ "$bits" =~ ^[0-9]+$ && "$bits" -ge 0 && "$bits" -le 32 ]] || return 1
    ip_i="$(_queue_endpoint_ipv4_to_int "$ip")" || return 1
    base_i="$(_queue_endpoint_ipv4_to_int "$base")" || return 1
    if (( bits == 0 )); then
        mask=0
    else
        mask=$(( (0xffffffff << (32 - bits)) & 0xffffffff ))
    fi
    (( (ip_i & mask) == (base_i & mask) ))
}

_queue_endpoint_region_for_ip() {
    local ip="$1" idx=1 spec cidr region key exact_key exact_val
    exact_key="QUEUEBASH_ENDPOINT_REGION_$(_queue_endpoint_norm_key "$ip")"
    exact_val="${!exact_key:-}"
    [[ -n "$exact_val" ]] && { printf '%s\n' "$exact_val"; return 0; }
    while :; do
        key="QUEUEBASH_ENDPOINT_CIDR_REGION_$idx"
        spec="${!key:-}"
        [[ -n "$spec" ]] || break
        cidr="${spec%%=*}"
        region="${spec#*=}"
        if [[ -n "$cidr" && -n "$region" ]] && _queue_endpoint_ip_in_cidr "$ip" "$cidr"; then
            printf '%s\n' "$region"
            return 0
        fi
        idx=$((idx + 1))
    done
    return 1
}

_queue_endpoint_region_for_host() {
    local host="$1" key val suffix_key suffix host_norm rest ip resolve_dns private_unknown
    [[ -n "$host" ]] || return 1
    key="QUEUEBASH_ENDPOINT_REGION_$(_queue_endpoint_norm_key "$host")"
    val="${!key:-}"
    [[ -n "$val" ]] && { printf '%s\n' "$val"; return 0; }

    # Suffix maps use host suffixes such as EXAMPLE_UK or SERVICE_INTERNAL.
    host_norm="$(_queue_endpoint_norm_key "$host")"
    for suffix_key in ${!QUEUEBASH_ENDPOINT_SUFFIX_REGION_*}; do
        suffix="${suffix_key#QUEUEBASH_ENDPOINT_SUFFIX_REGION_}"
        if [[ "$host_norm" == "$suffix" || "$host_norm" == *_"$suffix" ]]; then
            printf '%s\n' "${!suffix_key}"
            return 0
        fi
    done

    if _queue_endpoint_is_ipv4 "$host"; then
        _queue_endpoint_region_for_ip "$host" && return 0
        return 1
    fi

    resolve_dns="$(queue_asset_param resolve_dns "$@" || echo "${QUEUEBASH_ENDPOINT_RESOLVE_DNS:-1}")"
    if _queue_endpoint_bool "$resolve_dns" && command -v getent >/dev/null 2>&1; then
        while IFS= read -r ip rest; do
            [[ -n "$ip" ]] || continue
            _queue_endpoint_region_for_ip "$ip" && return 0
            if _queue_endpoint_ipv4_private "$ip"; then
                private_unknown=1
            fi
        done < <(getent ahostsv4 "$host" 2>/dev/null | awk '{print $1}' | sort -u)
    fi

    if [[ "${private_unknown:-0}" == 1 ]]; then
        return 2
    fi
    return 1
}

_queue_endpoint_region_for_target() {
    local target="$1" host explicit region rc allow_private_unknown
    shift || true
    explicit="$(queue_asset_param target_region "$@" || queue_asset_param region "$@" || true)"
    [[ -n "$explicit" ]] && { printf '%s\n' "$explicit"; return 0; }
    host="$(_queue_endpoint_host_from_target "$target")"
    [[ -n "$host" ]] || return 1
    region="$(_queue_endpoint_region_for_host "$host" "$@")"
    rc="$?"
    if [[ "$rc" -eq 0 && -n "$region" ]]; then
        printf '%s\n' "$region"
        return 0
    fi
    if [[ "$rc" -eq 2 ]]; then
        allow_private_unknown="$(queue_asset_param allow_private_unknown "$@" || echo "${QUEUEBASH_ENDPOINT_ALLOW_PRIVATE_UNKNOWN:-0}")"
        if _queue_endpoint_bool "$allow_private_unknown"; then
            printf '%s\n' "private"
            return 0
        fi
    fi
    return 1
}

_queue_endpoint_extract_command_targets() {
    local n i var tok
    n="${QUEUEBASH_COMMAND_COUNT:-0}"
    [[ "$n" =~ ^[0-9]+$ ]] || n=0
    for ((i=0; i<n; i++)); do
        var="QUEUEBASH_COMMAND_$i"
        tok="${!var:-}"
        [[ -n "$tok" ]] || continue
        case "$tok" in
            http://*|https://*) printf '%s\n' "$tok" ;;
            *@*:*|*://*) : ;;
            *.*:*) printf '%s\n' "$tok" ;;
        esac
    done | sed 's/[),;]$//' | sort -u
}

_queue_endpoint_check_region_allowed() {
    local token="$1" target="$2" allowed="$3"; shift 3 || true
    local region host
    [[ -n "$target" ]] || { echo "asset_check_blocked: endpoint target_required"; return 1; }
    [[ -n "$allowed" ]] || { echo "asset_check_blocked: endpoint allowed_regions_required"; return 1; }
    _queue_endpoint_load_policy "$@" || true
    region="$(_queue_endpoint_region_for_target "$target" "$@")" || {
        host="$(_queue_endpoint_host_from_target "$target")"
        echo "asset_check_blocked: endpoint region_unknown target=$target host=$host"
        return 1
    }
    if _queue_endpoint_csv_has "$allowed" "$region"; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: endpoint region_disallowed target=$target region=$region allowed=$allowed"
    return 1
}

queue_asset_check_endpoint_region_allowed() {
    local token="$1" target="$2"; shift 2 || true
    local allowed
    allowed="$(queue_asset_param regions "$@" || queue_asset_param allowed_regions "$@" || true)"
    _queue_endpoint_check_region_allowed "$token" "$target" "$allowed" "$@"
}

queue_asset_check_endpoint_jurisdiction_allowed() {
    local token="$1" target="$2"; shift 2 || true
    local framework key allowed
    framework="$(queue_asset_param framework "$@" || queue_asset_param jurisdiction "$@" || true)"
    [[ -n "$framework" ]] || { echo "asset_check_blocked: endpoint:jurisdiction_allowed framework_required"; return 1; }
    _queue_endpoint_load_policy "$@" || { echo "asset_check_blocked: endpoint:jurisdiction_allowed missing_policy"; return 1; }
    key="LEGAL_FRAMEWORK_$(_queue_endpoint_norm_framework "$framework")_REGIONS"
    allowed="${!key:-}"
    [[ -n "$allowed" ]] || { echo "asset_check_blocked: endpoint:jurisdiction_allowed unknown_framework=$framework"; return 1; }
    _queue_endpoint_check_region_allowed "$token" "$target" "$allowed" "$@"
}

queue_asset_check_endpoint_command_region_allowed() {
    local token="$1" allowed="$2"; shift 2 || true
    local target count=0 rc=0 allow_empty
    [[ -n "$allowed" ]] || { echo "asset_check_blocked: endpoint:command_region_allowed allowed_regions_required"; return 1; }
    while IFS= read -r target; do
        [[ -n "$target" ]] || continue
        count=$((count + 1))
        _queue_endpoint_check_region_allowed "$token" "$target" "$allowed" "$@" || rc=1
    done < <(_queue_endpoint_extract_command_targets)
    if [[ "$count" -eq 0 ]]; then
        allow_empty="$(queue_asset_param allow_empty "$@" || echo 1)"
        if _queue_endpoint_bool "$allow_empty"; then
            echo "asset_check_ok: $token"
            return 0
        fi
        echo "asset_check_blocked: endpoint:command_region_allowed no_endpoints_found"
        return 1
    fi
    return "$rc"
}

queue_asset_check_endpoint_command_jurisdiction_allowed() {
    local token="$1" framework="$2"; shift 2 || true
    local key allowed
    [[ -n "$framework" ]] || { echo "asset_check_blocked: endpoint:command_jurisdiction_allowed framework_required"; return 1; }
    _queue_endpoint_load_policy "$@" || { echo "asset_check_blocked: endpoint:command_jurisdiction_allowed missing_policy"; return 1; }
    key="LEGAL_FRAMEWORK_$(_queue_endpoint_norm_framework "$framework")_REGIONS"
    allowed="${!key:-}"
    [[ -n "$allowed" ]] || { echo "asset_check_blocked: endpoint:command_jurisdiction_allowed unknown_framework=$framework"; return 1; }
    queue_asset_check_endpoint_command_region_allowed "$token" "$allowed" "$@"
}
