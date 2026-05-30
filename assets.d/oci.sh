#!/usr/bin/env bash
# bashqueues Oracle Cloud Infrastructure asset checks

_OCI_TIMEOUT="${OCI_TIMEOUT:-10}"
_OCI_METADATA_URL="http://169.254.169.254/opc/v2"

queue_asset_facilities() {
    cat <<'FACILITIES'
oci:auth_active	Validates that OCI instance principal or CLI auth is active
oci:instance_state	Validates OCI compute instance state via IMDS or OCI CLI
oci:object_storage_access	Validates access to an OCI Object Storage bucket using a pre-authenticated request or instance principal
oci:compartment_available	Validates that a specified OCI compartment is accessible
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
oci:auth_active	target=compartment_ocid or _	params=timeout=10 method=instance_principal|cli	example=queue_class_shared_asset oci auth_active _	notes=Checks OCI IMDS reachability or oci CLI session. Does not print any auth token.
oci:instance_state	target=instance_ocid	params=expected=running timeout=10 env_file=/path/env env_key=OCI_REGION	example=queue_class_shared_asset oci instance_state ocid1.instance.oc1... expected=running	notes=Requires oci CLI or IMDS access; uses instance_ocid from target.
oci:object_storage_access	target=namespace/bucket	params=par_url=... timeout=10	example=queue_class_shared_asset oci object_storage_access mynamespace/mybucket par_url=$OCI_PAR_URL	notes=Uses pre-authenticated request URL. PAR URL must not be logged.
oci:compartment_available	target=compartment_ocid	params=timeout=10 env_file=/path/env env_key=OCI_COMPARTMENT	example=queue_class_shared_asset oci compartment_available ocid1.compartment.oc1...	notes=Requires oci CLI with compartment read permission.
EOF_HINTS
}

_queue_asset_oci_param() { queue_asset_param "$@"; }

queue_asset_check_oci_auth_active() {
    local token="$1" compartment="$2"; shift 2 || true
    local timeout method
    timeout="$(_queue_asset_oci_param timeout "$@" || echo "$_OCI_TIMEOUT")"
    method="$(_queue_asset_oci_param method "$@" || echo "instance_principal")"

    if [[ "$method" == "instance_principal" ]]; then
        if ! command -v curl >/dev/null 2>&1; then
            echo "asset_check_blocked: oci:auth_active requires curl for IMDS check"
            return 1
        fi
        if timeout "$timeout" curl -fsS -H "Authorization: Bearer Oracle" \
            "$_OCI_METADATA_URL/instance/" >/dev/null 2>&1; then
            echo "asset_check_ok: $token"
            return 0
        fi
        echo "asset_check_blocked: oci:auth_active imds_unreachable method=instance_principal"
        return 1
    fi

    if [[ "$method" == "cli" ]]; then
        if ! command -v oci >/dev/null 2>&1; then
            echo "asset_check_blocked: oci:auth_active tool_missing=oci"
            return 1
        fi
        if timeout "$timeout" oci iam region list --output table >/dev/null 2>&1; then
            echo "asset_check_ok: $token"
            return 0
        fi
        echo "asset_check_blocked: oci:auth_active oci_cli_auth_failed"
        return 1
    fi

    echo "asset_check_blocked: oci:auth_active unsupported method=$method"
    return 1
}

queue_asset_check_oci_instance_state() {
    local token="$1" instance_ocid="$2"; shift 2 || true
    local timeout expected state env_file env_key region
    timeout="$(_queue_asset_oci_param timeout "$@" || echo "$_OCI_TIMEOUT")"
    expected="$(_queue_asset_oci_param expected "$@" || echo "running")"
    env_file="$(_queue_asset_oci_param env_file "$@" || true)"
    env_key="$(_queue_asset_oci_param env_key "$@" || echo "OCI_REGION")"
    region=""

    if [[ -n "$env_file" && -r "$env_file" && -n "$env_key" ]]; then
        region="$(grep -E "^${env_key}=" "$env_file" | head -n1 | cut -d= -f2- | sed 's/^"//; s/"$//')"
    fi
    region="${region:-${QUEUEBASH_OCI_REGION:-${QUEUEBASH_CLOUD_REGION:-}}}"

    if [[ -z "$instance_ocid" ]]; then
        echo "asset_check_blocked: oci:instance_state requires target=instance_ocid"
        return 1
    fi

    if ! command -v oci >/dev/null 2>&1; then
        echo "asset_check_blocked: oci:instance_state tool_missing=oci"
        return 1
    fi

    local extra_args=()
    [[ -n "$region" ]] && extra_args+=(--region "$region")

    state="$(timeout "$timeout" oci compute instance get \
        --instance-id "$instance_ocid" \
        "${extra_args[@]}" \
        --query 'data."lifecycle-state"' --raw-output 2>/dev/null || echo "")"

    state="$(echo "$state" | tr '[:upper:]' '[:lower:]')"

    if [[ "$state" == "$expected" ]]; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: oci:instance_state expected=$expected got=${state:-unknown} instance=$instance_ocid"
    return 1
}

queue_asset_check_oci_object_storage_access() {
    local token="$1" namespace_bucket="$2"; shift 2 || true
    local par_url timeout
    timeout="$(_queue_asset_oci_param timeout "$@" || echo "$_OCI_TIMEOUT")"
    par_url="$(_queue_asset_oci_param par_url "$@" || true)"

    if ! command -v curl >/dev/null 2>&1; then
        echo "asset_check_blocked: oci:object_storage_access requires curl"
        return 1
    fi

    if [[ -z "$namespace_bucket" ]]; then
        echo "asset_check_blocked: oci:object_storage_access requires target=namespace/bucket"
        return 1
    fi

    if [[ -z "$par_url" ]]; then
        echo "asset_check_blocked: oci:object_storage_access requires par_url="
        return 1
    fi

    if timeout "$timeout" curl -fsS "$par_url" >/dev/null 2>&1; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: oci:object_storage_access failed for $namespace_bucket"
    return 1
}

queue_asset_check_oci_compartment_available() {
    local token="$1" compartment_ocid="$2"; shift 2 || true
    local timeout env_file env_key region
    timeout="$(_queue_asset_oci_param timeout "$@" || echo "$_OCI_TIMEOUT")"
    env_file="$(_queue_asset_oci_param env_file "$@" || true)"
    env_key="$(_queue_asset_oci_param env_key "$@" || echo "OCI_COMPARTMENT")"

    if [[ -z "$compartment_ocid" ]]; then
        compartment_ocid="${QUEUEBASH_OCI_COMPARTMENT:-}"
    fi
    if [[ -n "$env_file" && -r "$env_file" && -n "$env_key" ]]; then
        compartment_ocid="$(grep -E "^${env_key}=" "$env_file" | head -n1 | cut -d= -f2- | sed 's/^"//; s/"$//')"
    fi

    if [[ -z "$compartment_ocid" ]]; then
        echo "asset_check_blocked: oci:compartment_available requires target=compartment_ocid or QUEUEBASH_OCI_COMPARTMENT"
        return 1
    fi

    if ! command -v oci >/dev/null 2>&1; then
        echo "asset_check_blocked: oci:compartment_available tool_missing=oci"
        return 1
    fi

    if timeout "$timeout" oci iam compartment get \
        --compartment-id "$compartment_ocid" \
        --query 'data."lifecycle-state"' --raw-output >/dev/null 2>&1; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: oci:compartment_available inaccessible: $compartment_ocid"
    return 1
}
