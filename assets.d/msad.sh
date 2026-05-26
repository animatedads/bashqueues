#!/usr/bin/env bash
# bashqueues Microsoft Active Directory asset checks (LDAP / Kerberos)

_MSAD_TIMEOUT="${MSAD_TIMEOUT:-10}"

queue_asset_facilities() {
    cat <<'FACILITIES'
msad:ldap_bind	Validates LDAP bind to an Active Directory domain controller
msad:kerberos_ticket	Checks that a valid Kerberos TGT exists for the current user
msad:group_membership	Validates that an AD user is a member of a supplied group DN
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
msad:ldap_bind	target=ldap://dc.example.com	params=bind_dn=... password=... base=DC=example,DC=com timeout=10	example=queue_class_shared_asset msad ldap_bind ldap://dc.example.com bind_dn=CN=svc,DC=example,DC=com password=$MSAD_BIND_PASSWORD base=DC=example,DC=com	notes=Uses ldapsearch -x and fails closed. Do not put real passwords in committed class files.
msad:kerberos_ticket	target=_	params=none	example=queue_class_shared_asset msad kerberos_ticket _	notes=Uses klist and checks for a default principal.
msad:group_membership	target=user_sam	params=uri=ldap://dc.example.com bind_dn=... password=... base=... group_dn=... timeout=10	example=queue_class_shared_asset msad group_membership jbloggs uri=ldap://dc.example.com bind_dn=... password=$MSAD_BIND_PASSWORD base=DC=example,DC=com group_dn='CN=Ops,OU=Groups,DC=example,DC=com'	notes=Searches memberOf values for the supplied group DN.
EOF_HINTS
}

_queue_asset_msad_param() {
    queue_asset_param "$@"
}

queue_asset_check_msad_ldap_bind() {
    local token="$1" target="$2"; shift 2 || true
    local bind_dn password base timeout uri
    uri="${target:-ldap://dc.example.com}"
    bind_dn="$(_queue_asset_msad_param bind_dn "$@" || true)"
    password="$(_queue_asset_msad_param password "$@" || true)"
    base="$(_queue_asset_msad_param base "$@" || echo "")"
    timeout="$(_queue_asset_msad_param timeout "$@" || echo "$_MSAD_TIMEOUT")"

    if ! command -v ldapsearch >/dev/null 2>&1; then
        echo "asset_check_blocked: msad:ldap_bind requires ldapsearch"
        return 1
    fi
    if [[ -z "$bind_dn" || -z "$password" ]]; then
        echo "asset_check_blocked: msad:ldap_bind requires bind_dn= and password="
        return 1
    fi
    if timeout "$timeout" ldapsearch -x -H "$uri" -D "$bind_dn" -w "$password" -b "$base" -s base '(objectClass=*)' >/dev/null 2>&1; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: msad:ldap_bind failed uri=$uri bind_dn=$bind_dn"
    return 1
}

queue_asset_check_msad_kerberos_ticket() {
    local token="$1" _target="$2"; shift 2 || true
    if ! command -v klist >/dev/null 2>&1; then
        echo "asset_check_blocked: msad:kerberos_ticket requires klist"
        return 1
    fi
    if klist 2>/dev/null | grep -q 'Default principal:'; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: msad:kerberos_ticket no valid TGT found"
    return 1
}

queue_asset_check_msad_group_membership() {
    local token="$1" user_sam="$2"; shift 2 || true
    local group_dn bind_dn password base uri timeout
    uri="$(_queue_asset_msad_param uri "$@" || echo "ldap://dc.example.com")"
    bind_dn="$(_queue_asset_msad_param bind_dn "$@" || true)"
    password="$(_queue_asset_msad_param password "$@" || true)"
    base="$(_queue_asset_msad_param base "$@" || true)"
    group_dn="$(_queue_asset_msad_param group_dn "$@" || true)"
    timeout="$(_queue_asset_msad_param timeout "$@" || echo "$_MSAD_TIMEOUT")"

    if ! command -v ldapsearch >/dev/null 2>&1; then
        echo "asset_check_blocked: msad:group_membership requires ldapsearch"
        return 1
    fi
    if [[ -z "$bind_dn" || -z "$password" || -z "$group_dn" || -z "$base" || -z "$user_sam" ]]; then
        echo "asset_check_blocked: msad:group_membership requires bind_dn= password= base= group_dn= and target=user_sam"
        return 1
    fi
    if timeout "$timeout" ldapsearch -x -H "$uri" -D "$bind_dn" -w "$password" -b "$base" "(sAMAccountName=$user_sam)" memberOf 2>/dev/null | grep -Fqi "$group_dn"; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: msad:group_membership user=$user_sam not in required group"
    return 1
}
