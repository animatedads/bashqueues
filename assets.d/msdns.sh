#!/usr/bin/env bash
# bashqueues Microsoft / AD-integrated DNS asset checks

_MSDNS_TIMEOUT="${MSDNS_TIMEOUT:-5}"

queue_asset_facilities() {
    cat <<'FACILITIES'
msdns:record_exists	Validates that a DNS record exists using dig
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
msdns:record_exists	target=name.example.com	params=type=A|SRV|CNAME server=dc.example.com timeout=5	example=queue_class_shared_asset msdns record_exists _ldap._tcp.example.com type=SRV server=dc.example.com	notes=Uses dig +short and fails closed when no record is returned.
EOF_HINTS
}

_queue_asset_msdns_param() { queue_asset_param "$@"; }

queue_asset_check_msdns_record_exists() {
    local token="$1" name="$2"; shift 2 || true
    local type server timeout out
    type="$(_queue_asset_msdns_param type "$@" || echo "A")"
    server="$(_queue_asset_msdns_param server "$@" || true)"
    timeout="$(_queue_asset_msdns_param timeout "$@" || echo "$_MSDNS_TIMEOUT")"
    if ! command -v dig >/dev/null 2>&1; then
        echo "asset_check_blocked: msdns:record_exists requires dig"
        return 1
    fi
    if [[ -z "$name" ]]; then
        echo "asset_check_blocked: msdns:record_exists requires target=name"
        return 1
    fi
    if [[ -n "$server" ]]; then
        out="$(timeout "$timeout" dig +short "@$server" "$name" "$type" 2>/dev/null || true)"
    else
        out="$(timeout "$timeout" dig +short "$name" "$type" 2>/dev/null || true)"
    fi
    if [[ -n "$out" ]]; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: msdns:record_exists no $type record for $name"
    return 1
}
