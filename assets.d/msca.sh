#!/usr/bin/env bash
# bashqueues Microsoft AD Certificate Services asset checks

_MSCA_TIMEOUT="${MSCA_TIMEOUT:-10}"

queue_asset_facilities() {
    cat <<'FACILITIES'
msca:crl_valid	Validates that a CRL URL is reachable and returns content
msca:ocsp_status	Validates OCSP responder reachability with a lightweight HTTP probe
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
msca:crl_valid	target=http://ca.example.com/pki/root.crl	params=timeout=10	example=queue_class_shared_asset msca crl_valid http://ca.example.com/pki/root.crl	notes=Fetches the CRL URL and requires non-empty output.
msca:ocsp_status	target=http://ocsp.example.com	params=timeout=10	example=queue_class_shared_asset msca ocsp_status http://ocsp.example.com	notes=Lightweight reachability probe, not certificate-specific OCSP validation.
EOF_HINTS
}

_queue_asset_msca_param() { queue_asset_param "$@"; }

queue_asset_check_msca_crl_valid() {
    local token="$1" crl_url="$2"; shift 2 || true
    local timeout out
    timeout="$(_queue_asset_msca_param timeout "$@" || echo "$_MSCA_TIMEOUT")"
    if ! command -v curl >/dev/null 2>&1; then
        echo "asset_check_blocked: msca:crl_valid requires curl"
        return 1
    fi
    if [[ -z "$crl_url" ]]; then
        echo "asset_check_blocked: msca:crl_valid requires target=crl_url"
        return 1
    fi
    out="$(timeout "$timeout" curl -fsS "$crl_url" 2>/dev/null || true)"
    if [[ -n "$out" ]]; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: msca:crl_valid CRL fetch failed or empty"
    return 1
}

queue_asset_check_msca_ocsp_status() {
    local token="$1" ocsp_url="$2"; shift 2 || true
    local timeout
    timeout="$(_queue_asset_msca_param timeout "$@" || echo "$_MSCA_TIMEOUT")"
    if ! command -v curl >/dev/null 2>&1; then
        echo "asset_check_blocked: msca:ocsp_status requires curl"
        return 1
    fi
    if [[ -z "$ocsp_url" ]]; then
        echo "asset_check_blocked: msca:ocsp_status requires target=ocsp_url"
        return 1
    fi
    if timeout "$timeout" curl -fsI "$ocsp_url" >/dev/null 2>&1; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: msca:ocsp_status OCSP responder unreachable"
    return 1
}
