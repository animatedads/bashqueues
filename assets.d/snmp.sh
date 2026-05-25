#!/usr/bin/env bash
# bashqueues standard SNMP asset checks
#
# Facilities published:
#   snmp:int_below
#   snmp:int_above
#   snmp:truth_ok
#   snmp:string_match
#
# These checks intentionally fail closed.  SNMP is often monitoring/control-plane
# data, so an unreadable OID, missing tool, timeout, or type mismatch blocks
# dispatch rather than silently allowing the job to run.

queue_asset_facilities() {
    cat <<'FACILITIES'
snmp:int_below	Checks that a numeric SNMP OID value is below a maximum threshold
snmp:int_above	Checks that a numeric SNMP OID value is above a minimum threshold
snmp:truth_ok	Checks that a TruthValue/integer SNMP OID matches an expected integer state
snmp:string_match	Checks that an OctetString SNMP OID exactly or partially matches expected text
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
snmp:int_below	target=SNMP host/IP or map alias	params=oid=.1.3...|map=ALIAS max=80 comm=public v=2c timeout=5 retries=1	example=queue_class_shared_asset snmp int_below SAN_CPU max=85	notes=Blocks dispatch unless snmpget returns an integer lower than max. OIDs may come from /etc/bashqueues/snmp-map.env.
snmp:int_above	target=SNMP host/IP or map alias	params=oid=.1.3...|map=ALIAS min=1000 comm=public v=2c timeout=5 retries=1	example=queue_class_shared_asset snmp int_above CORE_IF_IN min=1000	notes=Blocks dispatch unless snmpget returns an integer greater than min. OIDs may come from /etc/bashqueues/snmp-map.env.
snmp:truth_ok	target=SNMP host/IP or map alias	params=oid=.1.3...|map=ALIAS expect_int=1 comm=public v=2c timeout=5 retries=1	example=queue_class_shared_asset snmp truth_ok MAINT_WINDOW expect_int=1	notes=Blocks dispatch unless the OID returns the expected integer state. OIDs may come from /etc/bashqueues/snmp-map.env.
snmp:string_match	target=SNMP host/IP or map alias	params=oid=.1.3...|map=ALIAS expect_str=Active match=exact|contains comm=public v=2c timeout=5 retries=1	example=queue_class_shared_asset snmp string_match SITE_STATE expect_str="Active" match=exact	notes=Blocks dispatch unless the OctetString matches the expected value. OIDs may come from /etc/bashqueues/snmp-map.env.
EOF_HINTS
}


_queue_asset_snmp_loaded_map=0

_queue_asset_snmp_map_candidates() {
    local plugin_dir repo_root qroot
    plugin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
    repo_root="$(cd "$plugin_dir/.." >/dev/null 2>&1 && pwd -P)"
    qroot="${QUEUEBASH_ROOT:-${HOME:-}/.queuebash}"
    printf '%s\n' \
        "/etc/bashqueues/snmp-map.env" \
        "/etc/bashqueues/snmp.d/default.env" \
        "$qroot/policies.d/snmp-map/default.env" \
        "$repo_root/policies.d/snmp-map/default.env"
}

_queue_asset_snmp_load_map() {
    (( _queue_asset_snmp_loaded_map )) && return 0
    _queue_asset_snmp_loaded_map=1
    local f
    while IFS= read -r f; do
        [[ -r "$f" ]] || continue
        # SNMP maps are trusted local policy files.  They deliberately use the
        # same env-file convention as class and policy files so admins can keep
        # OID meaning in one place instead of scattering numeric OIDs through
        # many class definitions.
        # shellcheck disable=SC1090
        source "$f"
    done < <(_queue_asset_snmp_map_candidates)
}

_queue_asset_snmp_alias_key() {
    local raw="$1"
    raw="${raw#@}"
    printf '%s' "$raw" | tr '[:lower:]-.' '[:upper:]__' | sed 's/[^A-Z0-9_]/_/g; s/^_\+//; s/_\+$//'
}

_queue_asset_snmp_has_param() {
    local key="$1" p
    shift || true
    for p in "$@"; do
        [[ "$p" == "$key="* ]] && return 0
    done
    return 1
}

_queue_asset_snmp_resolve_map() {
    local facility="$1" target="$2"
    shift 2 || true
    local alias key var val oid_param map_param

    _QUEUE_ASSET_SNMP_RESOLVED_TARGET="$target"
    _QUEUE_ASSET_SNMP_RESOLVED_PARAMS=("$@")

    map_param="$(queue_asset_param map "$@" || true)"
    oid_param="$(queue_asset_param oid "$@" || true)"
    if [[ -n "$map_param" ]]; then
        alias="$map_param"
    elif [[ "$target" == @* ]]; then
        alias="${target#@}"
    elif [[ -z "$oid_param" ]]; then
        alias="$target"
    else
        return 0
    fi

    if [[ -z "$alias" ]]; then
        echo "asset_check_blocked: $facility empty SNMP map alias"
        return 1
    fi

    _queue_asset_snmp_load_map
    key="$(_queue_asset_snmp_alias_key "$alias")"
    if [[ -z "$key" ]]; then
        echo "asset_check_blocked: $facility invalid SNMP map alias: $alias"
        return 1
    fi

    var="SNMP_MAP_${key}_TARGET"; val="${!var:-}"
    if [[ -z "$val" ]]; then
        if [[ -n "$oid_param" ]]; then
            return 0
        fi
        echo "asset_check_blocked: $facility unknown SNMP map alias: $alias"
        return 1
    fi
    _QUEUE_ASSET_SNMP_RESOLVED_TARGET="$val"

    local extra=()
    for field in OID COMM V VERSION TIMEOUT RETRIES MIN MAX EXPECT_INT EXPECT_STR MATCH; do
        var="SNMP_MAP_${key}_${field}"
        val="${!var:-}"
        [[ -n "$val" ]] || continue
        case "$field" in
            VERSION) extra+=("v=$val") ;;
            *) extra+=("$(printf '%s' "$field" | tr '[:upper:]' '[:lower:]')=$val") ;;
        esac
    done

    # Explicit class parameters come first and override map defaults because
    # queue_asset_param returns the first matching key.
    _QUEUE_ASSET_SNMP_RESOLVED_PARAMS=("$@" "${extra[@]}")
}

queue_asset_param() {
    local key="$1"
    shift
    local p
    for p in "$@"; do
        case "$p" in
            "$key="*) printf '%s\n' "${p#*=}"; return 0 ;;
        esac
    done
    return 1
}

_queue_asset_snmp_param_required() {
    local key="$1"
    shift
    local value
    value="$(queue_asset_param "$key" "$@" || true)"
    if [[ -z "$value" ]]; then
        echo "asset_check_blocked: snmp requires $key= parameter"
        return 1
    fi
    printf '%s\n' "$value"
}

_queue_asset_snmp_get() {
    local facility="$1" target="$2"
    shift 2 || true
    local oid comm version timeout_s retries val rc

    if [[ -z "$target" ]]; then
        echo "asset_check_blocked: $facility requires target host/IP or SNMP map alias"
        return 1
    fi

    _queue_asset_snmp_resolve_map "$facility" "$target" "$@" || return 1
    target="$_QUEUE_ASSET_SNMP_RESOLVED_TARGET"
    set -- "${_QUEUE_ASSET_SNMP_RESOLVED_PARAMS[@]}"

    oid="$(_queue_asset_snmp_param_required oid "$@")" || return 1
    comm="$(queue_asset_param comm "$@" || echo public)"
    version="$(queue_asset_param v "$@" || echo 2c)"
    timeout_s="$(queue_asset_param timeout "$@" || echo 5)"
    retries="$(queue_asset_param retries "$@" || echo 1)"

    case "$version" in
        1|2c) ;;
        *) echo "asset_check_blocked: $facility unsupported snmp version: $version"; return 1 ;;
    esac

    if [[ ! "$timeout_s" =~ ^[0-9]+$ || "$timeout_s" -lt 1 ]]; then
        echo "asset_check_blocked: $facility invalid timeout=$timeout_s"
        return 1
    fi
    if [[ ! "$retries" =~ ^[0-9]+$ ]]; then
        echo "asset_check_blocked: $facility invalid retries=$retries"
        return 1
    fi

    if ! command -v snmpget >/dev/null 2>&1; then
        echo "asset_check_blocked: $facility tool_missing=snmpget"
        return 1
    fi

    # -Oqv returns only the value component.  That keeps numeric comparisons
    # from accidentally parsing MIB/type text such as "Gauge32: 45".
    val="$(snmpget -Oqv -v"$version" -c "$comm" -t "$timeout_s" -r "$retries" -- "$target" "$oid" 2>&1)"
    rc=$?
    if (( rc != 0 )); then
        val="${val//$'\n'/ }"
        echo "asset_check_blocked: $facility snmpget_failed rc=$rc target=$target oid=$oid detail=${val:-none}"
        return 1
    fi

    # Net-SNMP may quote strings.  Preserve interior spaces, but trim one outer
    # pair of quotes for string comparisons and integer type checks.
    val="${val%$'\r'}"
    if [[ "$val" == '"'*'"' && ${#val} -ge 2 ]]; then
        val="${val:1:${#val}-2}"
    fi

    printf '%s\n' "$val"
}

_queue_asset_snmp_require_uint() {
    local facility="$1" val="$2"
    if [[ ! "$val" =~ ^[0-9]+$ ]]; then
        echo "asset_check_blocked: $facility invalid_smi_type_returned value=${val:-empty}"
        return 1
    fi
}

queue_asset_check_snmp_int_below() {
    local target="$1"
    shift || true
    local max val
    _queue_asset_snmp_resolve_map snmp:int_below "$target" "$@" || return 1
    target="$_QUEUE_ASSET_SNMP_RESOLVED_TARGET"
    set -- "${_QUEUE_ASSET_SNMP_RESOLVED_PARAMS[@]}"
    max="$(_queue_asset_snmp_param_required max "$@")" || return 1
    if [[ ! "$max" =~ ^[0-9]+$ ]]; then
        echo "asset_check_blocked: snmp:int_below invalid max=$max"
        return 1
    fi
    val="$(_queue_asset_snmp_get snmp:int_below "$target" "$@")" || return 1
    _queue_asset_snmp_require_uint snmp:int_below "$val" || return 1
    if (( val < max )); then
        echo "asset_check_ok: snmp:int_below target=$target value=$val max=$max"
        return 0
    fi
    echo "asset_check_blocked: snmp:int_below target=$target value=$val max=$max"
    return 1
}

queue_asset_check_snmp_int_above() {
    local target="$1"
    shift || true
    local min val
    _queue_asset_snmp_resolve_map snmp:int_above "$target" "$@" || return 1
    target="$_QUEUE_ASSET_SNMP_RESOLVED_TARGET"
    set -- "${_QUEUE_ASSET_SNMP_RESOLVED_PARAMS[@]}"
    min="$(_queue_asset_snmp_param_required min "$@")" || return 1
    if [[ ! "$min" =~ ^[0-9]+$ ]]; then
        echo "asset_check_blocked: snmp:int_above invalid min=$min"
        return 1
    fi
    val="$(_queue_asset_snmp_get snmp:int_above "$target" "$@")" || return 1
    _queue_asset_snmp_require_uint snmp:int_above "$val" || return 1
    if (( val > min )); then
        echo "asset_check_ok: snmp:int_above target=$target value=$val min=$min"
        return 0
    fi
    echo "asset_check_blocked: snmp:int_above target=$target value=$val min=$min"
    return 1
}

queue_asset_check_snmp_truth_ok() {
    local target="$1"
    shift || true
    local expect val
    _queue_asset_snmp_resolve_map snmp:truth_ok "$target" "$@" || return 1
    target="$_QUEUE_ASSET_SNMP_RESOLVED_TARGET"
    set -- "${_QUEUE_ASSET_SNMP_RESOLVED_PARAMS[@]}"
    expect="$(queue_asset_param expect_int "$@" || echo 1)"
    if [[ ! "$expect" =~ ^[0-9]+$ ]]; then
        echo "asset_check_blocked: snmp:truth_ok invalid expect_int=$expect"
        return 1
    fi
    val="$(_queue_asset_snmp_get snmp:truth_ok "$target" "$@")" || return 1
    _queue_asset_snmp_require_uint snmp:truth_ok "$val" || return 1
    if (( val == expect )); then
        echo "asset_check_ok: snmp:truth_ok target=$target value=$val expect_int=$expect"
        return 0
    fi
    echo "asset_check_blocked: snmp:truth_ok target=$target value=$val expect_int=$expect"
    return 1
}

queue_asset_check_snmp_string_match() {
    local target="$1"
    shift || true
    local expect match val
    _queue_asset_snmp_resolve_map snmp:string_match "$target" "$@" || return 1
    target="$_QUEUE_ASSET_SNMP_RESOLVED_TARGET"
    set -- "${_QUEUE_ASSET_SNMP_RESOLVED_PARAMS[@]}"
    expect="$(_queue_asset_snmp_param_required expect_str "$@")" || return 1
    match="$(queue_asset_param match "$@" || echo exact)"
    case "$match" in
        exact)
            val="$(_queue_asset_snmp_get snmp:string_match "$target" "$@")" || return 1
            if [[ "$val" == "$expect" ]]; then
                echo "asset_check_ok: snmp:string_match target=$target match=exact"
                return 0
            fi
            ;;
        contains)
            val="$(_queue_asset_snmp_get snmp:string_match "$target" "$@")" || return 1
            if [[ "$val" == *"$expect"* ]]; then
                echo "asset_check_ok: snmp:string_match target=$target match=contains"
                return 0
            fi
            ;;
        *)
            echo "asset_check_blocked: snmp:string_match invalid match=$match"
            return 1
            ;;
    esac
    echo "asset_check_blocked: snmp:string_match target=$target match=$match expected=$expect actual=$val"
    return 1
}
