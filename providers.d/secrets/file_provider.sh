#!/usr/bin/env bash
# queuebash fixture file-backed secrets provider.
# It is for dev/test contracts and never performs live cloud/Vault calls.
set -euo pipefail

_json() {
    local s="${1:-}"
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    s=${s//$'\r'/\\r}
    s=${s//$'\t'/\\t}
    printf '"%s"' "$s"
}
_json_error() {
    local code="${1:-error}" message="${2:-secret provider error}" rc="${3:-1}" json="${4:-0}"
    if [[ "$json" -eq 1 ]]; then
        printf '{"schema":"queuebash.error.v1","ok":false,"error":{"code":%s,"message":%s,"rc":%s}}\n' "$(_json "$code")" "$(_json "$message")" "$rc"
    else
        echo "file secrets provider: $message" >&2
    fi
    return "$rc"
}
_secret_sanitize_name() {
    local s="${1:-}"
    [[ "$s" =~ ^[A-Za-z0-9_.-]+$ ]] || return 1
    printf '%s\n' "$s"
}
_secret_ref_to_file_name() {
    local ref="${1:-}"
    [[ -n "$ref" ]] || return 1
    [[ "$ref" != *".."* && "$ref" != /* && "$ref" != *"//"* ]] || return 1
    ref="${ref//\//__}"
    [[ "$ref" =~ ^[A-Za-z0-9_.:@=-]+(__[A-Za-z0-9_.:@=-]+)*$ ]] || return 1
    printf '%s.secret\n' "$ref"
}
_secret_fixture_dir() {
    if [[ -n "${QUEUEBASH_SECRETS_FILE_PROVIDER_DIR:-}" ]]; then
        printf '%s\n' "$QUEUEBASH_SECRETS_FILE_PROVIDER_DIR"
    elif [[ -n "${QUEUEBASH_ROOT:-}" ]]; then
        printf '%s\n' "$QUEUEBASH_ROOT/policies.d/secrets/fixtures"
    else
        printf '%s\n' "$HOME/.queuebash/policies.d/secrets/fixtures"
    fi
}

_secret_policy_dir() {
    if [[ -n "${QUEUEBASH_SECRETS_POLICY_DIR:-}" ]]; then
        printf '%s\n' "$QUEUEBASH_SECRETS_POLICY_DIR"
    elif [[ -n "${QUEUEBASH_ROOT:-}" ]]; then
        printf '%s\n' "$QUEUEBASH_ROOT/policies.d/secrets"
    else
        printf '%s\n' "$HOME/.queuebash/policies.d/secrets"
    fi
}
_secret_policy_class_allowed() {
    local class="${1:-}" delivery="${2:-file}" json="${3:-0}" policy_dir file line cls uses allowed_delivery env_allowed refresh_allowed found=0
    policy_dir="$(_secret_policy_dir)"
    file="$policy_dir/class-bindings.tsv"
    [[ -f "$file" ]] || return 0
    while IFS=$'\t' read -r cls uses allowed_delivery env_allowed refresh_allowed _rest; do
        [[ -z "${cls:-}" || "${cls:0:1}" == "#" ]] && continue
        if [[ "$cls" == "$class" ]]; then
            found=1
            [[ "${uses:-0}" == "1" ]] || { _json_error class_denied "class is not permitted to request secrets" 4 "$json"; return $?; }
            [[ -z "${allowed_delivery:-}" || "$allowed_delivery" == "$delivery" ]] || { _json_error delivery_denied "delivery mode is not permitted for class" 4 "$json"; return $?; }
            if [[ "$delivery" == "env" && "${env_allowed:-0}" != "1" ]]; then
                _json_error delivery_denied "environment secret delivery is denied for class" 4 "$json"; return $?
            fi
            return 0
        fi
    done < "$file"
    if [[ "$found" -eq 0 ]]; then
        _json_error class_denied "class has no active secret binding" 4 "$json"; return $?
    fi
}
_secret_policy_acl_allowed() {
    local class="${1:-}" secret_ref="${2:-}" purpose="${3:-}" delivery="${4:-file}" ttl="${5:-0}" json="${6:-0}" policy_dir file line cls ref purpose_pat allowed_delivery max_ttl matched=0
    policy_dir="$(_secret_policy_dir)"
    file="$policy_dir/secret-acl.tsv"
    [[ -f "$file" ]] || return 0
    while IFS=$'\t' read -r cls ref purpose_pat allowed_delivery max_ttl _rest; do
        [[ -z "${cls:-}" || "${cls:0:1}" == "#" ]] && continue
        [[ "$cls" == "$class" ]] || continue
        [[ "$ref" == "$secret_ref" || "$ref" == "*" ]] || continue
        [[ -z "${allowed_delivery:-}" || "$allowed_delivery" == "$delivery" ]] || continue
        if [[ -n "${purpose_pat:-}" && "$purpose_pat" != "*" ]]; then
            [[ "$purpose" == $purpose_pat ]] || continue
        fi
        if [[ -n "${max_ttl:-}" && "$max_ttl" =~ ^[0-9]+$ && "$ttl" =~ ^[0-9]+$ ]]; then
            if [[ "$ttl" -gt "$max_ttl" ]]; then
                _json_error ttl_exceeds_policy "secret ttl exceeds policy maximum" 4 "$json"; return $?
            fi
        fi
        matched=1
        break
    done < "$file"
    if [[ "$matched" -eq 1 ]]; then
        return 0
    fi
    _json_error acl_denied "secret request is not permitted by active secret ACL" 4 "$json"; return $?
}

_secret_run_dir() {
    if [[ -n "${QUEUEBASH_SECRET_RUN_DIR:-}" ]]; then
        printf '%s\n' "$QUEUEBASH_SECRET_RUN_DIR"
    elif [[ -n "${QUEUEBASH_ROOT:-}" ]]; then
        printf '%s\n' "$QUEUEBASH_ROOT/secrets/run"
    else
        printf '%s\n' "$HOME/.queuebash/secrets/run"
    fi
}

_secret_audit_dir() {
    if [[ -n "${QUEUEBASH_SECRET_AUDIT_DIR:-}" ]]; then
        printf '%s\n' "$QUEUEBASH_SECRET_AUDIT_DIR"
    elif [[ -n "${QUEUEBASH_ROOT:-}" ]]; then
        printf '%s\n' "$QUEUEBASH_ROOT/secrets/audit"
    else
        printf '%s\n' "$HOME/.queuebash/secrets/audit"
    fi
}
_secret_hash() {
    local s="${1:-}"
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s' "$s" | sha256sum | awk '{print $1}'
    else
        printf '%s' "$s" | cksum | awk '{print $1}'
    fi
}

_secret_manifest_path() {
    local qid="${1:-}" run_dir
    run_dir="$(_secret_run_dir)"
    printf '%s/%s/.queuebash_secret_manifest.jsonl\n' "$run_dir" "$qid"
}
_secret_cleanup_evidence_path() {
    local qid="${1:-}" audit_dir safe_qid
    audit_dir="$(_secret_audit_dir)"
    safe_qid="${qid//[^A-Za-z0-9_.:-]/_}"
    printf '%s/secret_cleanup_%s.json\n' "$audit_dir" "$safe_qid"
}
_secret_manifest_seal_path() {
    local qid="${1:-}" audit_dir safe_qid
    audit_dir="$(_secret_audit_dir)"
    safe_qid="${qid//[^A-Za-z0-9_.:-]/_}"
    printf '%s/secret_manifest_seal_%s.json\n' "$audit_dir" "$safe_qid"
}
_secret_file_hash() {
    local file="${1:-}"
    [[ -f "$file" ]] || return 1
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    else
        cksum "$file" | awk '{print $1}'
    fi
}
_secret_manifest_emit() {
    local qid="${1:-}" name="${2:-}" secret_ref="${3:-}" class="${4:-}" delivery="${5:-file}" path="${6:-}" ttl="${7:-0}" manifest ts ref_hash path_hash
    [[ -n "$qid" && -n "$name" && -n "$path" ]] || return 0
    manifest="$(_secret_manifest_path "$qid")"
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf '1970-01-01T00:00:00Z')"
    ref_hash="$(_secret_hash "$secret_ref" 2>/dev/null || true)"
    path_hash="$(_secret_hash "$path" 2>/dev/null || true)"
    mkdir -p -- "$(dirname -- "$manifest")" 2>/dev/null || return 0
    chmod 700 -- "$(dirname -- "$manifest")" 2>/dev/null || true
    printf '{"schema":"queuebash.secret_delivery_manifest.v1","qid":%s,"name":%s,"provider":"file","class":%s,"secret_ref_hash":%s,"delivery":%s,"path":%s,"path_hash":%s,"ttl_seconds":%s,"created_at":%s,"redacted":true,"secret_value_included":false}\n' \
        "$(_json "$qid")" "$(_json "$name")" "$(_json "$class")" "$(_json "$ref_hash")" "$(_json "$delivery")" "$(_json "$path")" "$(_json "$path_hash")" "$ttl" "$(_json "$ts")" >> "$manifest" 2>/dev/null || true
    chmod 600 -- "$manifest" 2>/dev/null || true
}
_secret_count_manifest_entries() {
    local manifest="${1:-}"
    [[ -f "$manifest" ]] || { printf '0\n'; return 0; }
    wc -l < "$manifest" 2>/dev/null | tr -d ' ' || printf '0\n'
}
_secret_cleanup_evidence_emit() {
    local qid="${1:-}" removed="${2:-false}" manifest_entries="${3:-0}" unsafe_paths="${4:-0}" audit_dir evidence ts
    audit_dir="$(_secret_audit_dir)"
    mkdir -p -- "$audit_dir" 2>/dev/null || return 0
    chmod 700 -- "$audit_dir" 2>/dev/null || true
    evidence="$(_secret_cleanup_evidence_path "$qid")"
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf '1970-01-01T00:00:00Z')"
    printf '{"schema":"queuebash.secret_cleanup_evidence.v1","ok":true,"qid":%s,"removed":%s,"manifest_entries":%s,"unsafe_paths":%s,"redacted":true,"secret_value_included":false,"created_at":%s}\n' \
        "$(_json "$qid")" "$removed" "${manifest_entries:-0}" "${unsafe_paths:-0}" "$(_json "$ts")" > "$evidence" 2>/dev/null || true
    chmod 600 -- "$evidence" 2>/dev/null || true
}

_secret_audit_emit() {
    local event="${1:-secret.request}" status="${2:-unknown}" qid="${3:-}" name="${4:-}" secret_ref="${5:-}" class="${6:-}" purpose="${7:-}" delivery="${8:-file}" reason="${9:-}" audit_dir audit_log ts purpose_hash
    audit_dir="$(_secret_audit_dir)"
    mkdir -p -- "$audit_dir" 2>/dev/null || return 0
    chmod 700 -- "$audit_dir" 2>/dev/null || true
    audit_log="$audit_dir/secrets_audit.jsonl"
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf '1970-01-01T00:00:00Z')"
    purpose_hash="$(_secret_hash "$purpose" 2>/dev/null || true)"
    printf '{"schema":"queuebash.secret_audit_event.v1","event":%s,"status":%s,"provider":"file","qid":%s,"name":%s,"secret_ref":%s,"class":%s,"purpose_hash":%s,"delivery":%s,"reason_code":%s,"redacted":true,"secret_value_included":false,"created_at":%s}\n' \
        "$(_json "$event")" "$(_json "$status")" "$(_json "$qid")" "$(_json "$name")" "$(_json "$secret_ref")" "$(_json "$class")" "$(_json "$purpose_hash")" "$(_json "$delivery")" "$(_json "$reason")" "$(_json "$ts")" >> "$audit_log" 2>/dev/null || true
    chmod 600 -- "$audit_log" 2>/dev/null || true
}

_usage() {
    cat <<'USAGE'
providers.d/secrets/file_provider.sh explain SECRET_REF --class CLASS [--json]
providers.d/secrets/file_provider.sh request SECRET_REF --name NAME --class CLASS --purpose TEXT --qid QID [--delivery file] [--ttl-seconds N] [--max-runtime-seconds N] [--json]
providers.d/secrets/file_provider.sh cleanup QID [--json]
providers.d/secrets/file_provider.sh seal-manifest QID [--json]
providers.d/secrets/file_provider.sh verify-manifest QID [--json]
USAGE
}

_explain() {
    local secret_ref="${1:-}" class="" json=0 fixture_dir file_name exists=false
    [[ -n "$secret_ref" ]] || { _usage >&2; return 2; }
    shift || true
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --class) class="${2:-}"; shift 2 ;;
            --class=*) class="${1#--class=}"; shift ;;
            --json|-j) json=1; shift ;;
            *) echo "file secrets provider explain: unexpected argument: $1" >&2; return 2 ;;
        esac
    done
    [[ -n "$class" ]] || { _json_error missing_class "--class is required" 2 "$json"; return $?; }
    file_name="$(_secret_ref_to_file_name "$secret_ref" 2>/dev/null)" || { _json_error invalid_secret_ref "invalid secret reference" 2 "$json"; return $?; }
    fixture_dir="$(_secret_fixture_dir)"
    [[ -f "$fixture_dir/$file_name" ]] && exists=true
    if [[ "$json" -eq 1 ]]; then
        printf '{"schema":"queuebash.secret_explain.v1","ok":true,"provider":"file","secret_ref":%s,"class":%s,"delivery_modes":["file"],"secret_value_included":false,"fixture_present":%s}\n' "$(_json "$secret_ref")" "$(_json "$class")" "$exists"
    else
        echo "secret: $secret_ref"
        echo "provider: file"
        echo "class: $class"
        echo "delivery: file"
        echo "secret value: redacted"
        echo "fixture present: $exists"
    fi
}

_request() {
    local secret_ref="${1:-}" name="" class="" purpose="" qid="" delivery="file" ttl=1800 max_runtime=0 json=0 fixture_dir file_name src run_dir dest_dir dest value
    [[ -n "$secret_ref" ]] || { _usage >&2; return 2; }
    shift || true
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --name) name="${2:-}"; shift 2 ;;
            --name=*) name="${1#--name=}"; shift ;;
            --class) class="${2:-}"; shift 2 ;;
            --class=*) class="${1#--class=}"; shift ;;
            --purpose) purpose="${2:-}"; shift 2 ;;
            --purpose=*) purpose="${1#--purpose=}"; shift ;;
            --qid) qid="${2:-}"; shift 2 ;;
            --qid=*) qid="${1#--qid=}"; shift ;;
            --delivery) delivery="${2:-}"; shift 2 ;;
            --delivery=*) delivery="${1#--delivery=}"; shift ;;
            --ttl-seconds) ttl="${2:-}"; shift 2 ;;
            --ttl-seconds=*) ttl="${1#--ttl-seconds=}"; shift ;;
            --max-runtime-seconds) max_runtime="${2:-}"; shift 2 ;;
            --max-runtime-seconds=*) max_runtime="${1#--max-runtime-seconds=}"; shift ;;
            --json|-j) json=1; shift ;;
            *) _json_error unexpected_argument "unexpected argument: $1" 2 "$json"; return $? ;;
        esac
    done
    [[ -n "$name" ]] || { _json_error missing_name "--name is required" 2 "$json"; return $?; }
    [[ -n "$class" ]] || { _json_error missing_class "--class is required" 2 "$json"; return $?; }
    [[ -n "$purpose" ]] || { _json_error missing_purpose "--purpose is required" 2 "$json"; return $?; }
    [[ -n "$qid" ]] || { _json_error missing_qid "--qid is required" 2 "$json"; return $?; }
    _secret_sanitize_name "$name" >/dev/null || { _json_error invalid_name "invalid secret delivery name" 2 "$json"; return $?; }
    [[ "$qid" =~ ^[A-Za-z0-9_.:-]+$ ]] || { _json_error invalid_qid "invalid qid" 2 "$json"; return $?; }
    [[ "$ttl" =~ ^[0-9]+$ ]] || { _json_error invalid_ttl "ttl must be numeric seconds" 2 "$json"; return $?; }
    [[ "$max_runtime" =~ ^[0-9]+$ ]] || { _json_error invalid_runtime "max runtime must be numeric seconds" 2 "$json"; return $?; }
    if [[ "$delivery" != "file" ]]; then
        _json_error delivery_denied "secret environment/fd delivery is not enabled in the fixture provider; use file delivery" 4 "$json"; return $?
    fi
    if [[ "$max_runtime" -gt 0 && "$ttl" -lt "$max_runtime" ]]; then
        _json_error ttl_too_short "secret ttl is shorter than max runtime" 4 "$json"; return $?
    fi
    if _secret_policy_class_allowed "$class" "$delivery" "$json"; then
        :
    else
        rc=$?
        _secret_audit_emit "secret.request" "denied" "$qid" "$name" "$secret_ref" "$class" "$purpose" "$delivery" "class_or_delivery_denied"
        return "$rc"
    fi
    if _secret_policy_acl_allowed "$class" "$secret_ref" "$purpose" "$delivery" "$ttl" "$json"; then
        :
    else
        rc=$?
        _secret_audit_emit "secret.request" "denied" "$qid" "$name" "$secret_ref" "$class" "$purpose" "$delivery" "acl_or_ttl_denied"
        return "$rc"
    fi
    file_name="$(_secret_ref_to_file_name "$secret_ref" 2>/dev/null)" || { _secret_audit_emit "secret.request" "denied" "$qid" "$name" "$secret_ref" "$class" "$purpose" "$delivery" "invalid_secret_ref"; _json_error invalid_secret_ref "invalid secret reference" 2 "$json"; return $?; }
    fixture_dir="$(_secret_fixture_dir)"
    src="$fixture_dir/$file_name"
    [[ -f "$src" ]] || { _secret_audit_emit "secret.request" "denied" "$qid" "$name" "$secret_ref" "$class" "$purpose" "$delivery" "not_found"; _json_error not_found "fixture secret not found" 4 "$json"; return $?; }
    run_dir="$(_secret_run_dir)"
    dest_dir="$run_dir/$qid"
    dest="$dest_dir/$name"
    mkdir -p -- "$dest_dir"
    chmod 700 -- "$dest_dir" 2>/dev/null || true
    umask 077
    # Copy exactly, without echoing the secret to stdout/stderr.
    cat -- "$src" > "$dest"
    chmod 600 -- "$dest"
    _secret_manifest_emit "$qid" "$name" "$secret_ref" "$class" "$delivery" "$dest" "$ttl"
    _secret_audit_emit "secret.request" "ok" "$qid" "$name" "$secret_ref" "$class" "$purpose" "$delivery" "delivered"
    if [[ "$json" -eq 1 ]]; then
        printf '{"schema":"queuebash.secret_provider.result.v1","ok":true,"provider":"file","secret_ref":%s,"class":%s,"purpose":%s,"delivery":"file","path":%s,"ttl_seconds":%s,"secret_value_included":false,"redacted":true,"audit_id":%s}\n' "$(_json "$secret_ref")" "$(_json "$class")" "$(_json "$purpose")" "$(_json "$dest")" "$ttl" "$(_json "fixture-$qid-$name")"
    else
        echo "secret delivered: $name"
        echo "provider: file"
        echo "path: $dest"
        echo "secret value: redacted"
    fi
}

_cleanup() {
    local qid="${1:-}" json=0 run_dir target removed=false manifest manifest_entries=0 unsafe_paths=0 evidence
    [[ -n "$qid" ]] || { _usage >&2; return 2; }
    shift || true
    while [[ "$#" -gt 0 ]]; do
        case "$1" in --json|-j) json=1; shift ;; *) echo "file secrets provider cleanup: unexpected argument: $1" >&2; return 2 ;; esac
    done
    [[ "$qid" =~ ^[A-Za-z0-9_.:-]+$ ]] || { _json_error invalid_qid "invalid qid" 2 "$json"; return $?; }
    run_dir="$(_secret_run_dir)"
    target="$run_dir/$qid"
    case "$target" in
        "$run_dir"/*) ;;
        *) _json_error unsafe_cleanup_target "cleanup target escaped secret run directory" 5 "$json"; return $? ;;
    esac
    manifest="$(_secret_manifest_path "$qid")"
    manifest_entries="$(_secret_count_manifest_entries "$manifest")"
    if [[ -f "$manifest" ]] && grep -vF '"path":"' "$manifest" >/dev/null 2>&1; then
        unsafe_paths=1
    fi
    if [[ -d "$target" ]]; then rm -rf -- "$target"; removed=true; fi
    _secret_cleanup_evidence_emit "$qid" "$removed" "${manifest_entries:-0}" "$unsafe_paths"
    evidence="$(_secret_cleanup_evidence_path "$qid")"
    _secret_audit_emit "secret.cleanup" "ok" "$qid" "" "" "" "" "file" "removed=$removed"
    if [[ "$json" -eq 1 ]]; then
        printf '{"schema":"queuebash.secret_cleanup.v1","ok":true,"qid":%s,"removed":%s,"manifest_entries":%s,"cleanup_evidence":%s,"secret_value_included":false,"redacted":true}\n' "$(_json "$qid")" "$removed" "${manifest_entries:-0}" "$(_json "$evidence")"
    else
        echo "secret cleanup: $qid removed=$removed manifest_entries=${manifest_entries:-0}"
        echo "cleanup evidence: $evidence"
    fi
}


_secret_manifest_seal() {
    local qid="${1:-}" json=0 run_dir target manifest mode entries manifest_hash audit_dir seal ts
    [[ -n "$qid" ]] || { _usage >&2; return 2; }
    shift || true
    while [[ "$#" -gt 0 ]]; do
        case "$1" in --json|-j) json=1; shift ;; *) echo "file secrets provider seal-manifest: unexpected argument: $1" >&2; return 2 ;; esac
    done
    [[ "$qid" =~ ^[A-Za-z0-9_.:-]+$ ]] || { _json_error invalid_qid "invalid qid" 2 "$json"; return $?; }
    run_dir="$(_secret_run_dir)"
    target="$run_dir/$qid"
    case "$target" in
        "$run_dir"/*) ;;
        *) _json_error unsafe_manifest_target "manifest target escaped secret run directory" 5 "$json"; return $? ;;
    esac
    manifest="$(_secret_manifest_path "$qid")"
    if [[ ! -f "$manifest" ]]; then
        _json_error manifest_missing "secret delivery manifest is missing" 4 "$json"; return $?
    fi
    mode="$(stat -c '%a' "$manifest" 2>/dev/null || stat -f '%Lp' "$manifest" 2>/dev/null || printf 'unknown')"
    [[ "$mode" == "600" ]] || { _json_error insecure_manifest_permissions "secret delivery manifest must be mode 0600 before sealing" 4 "$json"; return $?; }
    entries="$(_secret_count_manifest_entries "$manifest")"
    manifest_hash="$(_secret_file_hash "$manifest")" || { _json_error manifest_hash_failed "could not hash secret delivery manifest" 5 "$json"; return $?; }
    audit_dir="$(_secret_audit_dir)"
    mkdir -p -- "$audit_dir" 2>/dev/null || { _json_error audit_dir_failed "could not create secret audit directory" 5 "$json"; return $?; }
    chmod 700 -- "$audit_dir" 2>/dev/null || true
    seal="$(_secret_manifest_seal_path "$qid")"
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf '1970-01-01T00:00:00Z')"
    printf '{"schema":"queuebash.secret_manifest_seal.v1","ok":true,"qid":%s,"manifest":%s,"manifest_hash":%s,"manifest_mode":%s,"entries":%s,"created_at":%s,"redacted":true,"secret_value_included":false}\n' \
        "$(_json "$qid")" "$(_json "$manifest")" "$(_json "$manifest_hash")" "$(_json "$mode")" "${entries:-0}" "$(_json "$ts")" > "$seal"
    chmod 600 -- "$seal" 2>/dev/null || true
    _secret_audit_emit "secret.manifest.seal" "ok" "$qid" "" "" "" "" "file" "entries=${entries:-0}"
    if [[ "$json" -eq 1 ]]; then
        cat -- "$seal"
    else
        echo "secret manifest seal: $qid entries=${entries:-0}"
        echo "seal: $seal"
    fi
}


_secret_manifest_verify() {
    local qid="${1:-}" json=0 run_dir target manifest mode entries=0 insecure_permissions=0 unsafe_paths=0 missing_paths=0 malformed_entries=0 secret_value_markers=0 ok=true evidence
    local qid_mismatches=0 missing_hashes=0 path_hash_mismatches=0
    local seal seal_status="absent" seal_hash="" current_hash="" seal_mode="absent" seal_schema_ok=0 seal_redacted_ok=0 seal_secret_value_marker_ok=0 seal_manifest_path_ok=0 seal_qid_ok=0 seal_hash_present=0 seal_invalid=0 seal_manifest_path="" seal_qid=""
    [[ -n "$qid" ]] || { _usage >&2; return 2; }
    shift || true
    while [[ "$#" -gt 0 ]]; do
        case "$1" in --json|-j) json=1; shift ;; *) echo "file secrets provider verify-manifest: unexpected argument: $1" >&2; return 2 ;; esac
    done
    [[ "$qid" =~ ^[A-Za-z0-9_.:-]+$ ]] || { _json_error invalid_qid "invalid qid" 2 "$json"; return $?; }
    run_dir="$(_secret_run_dir)"
    target="$run_dir/$qid"
    case "$target" in
        "$run_dir"/*) ;;
        *) _json_error unsafe_manifest_target "manifest target escaped secret run directory" 5 "$json"; return $? ;;
    esac
    manifest="$(_secret_manifest_path "$qid")"
    if [[ ! -f "$manifest" ]]; then
        _json_error manifest_missing "secret delivery manifest is missing" 4 "$json"; return $?
    fi
    mode="$(stat -c '%a' "$manifest" 2>/dev/null || stat -f '%Lp' "$manifest" 2>/dev/null || printf 'unknown')"
    [[ "$mode" == "600" ]] || insecure_permissions=1
    current_hash="$(_secret_file_hash "$manifest" 2>/dev/null || true)"
    seal="$(_secret_manifest_seal_path "$qid")"
    if [[ -f "$seal" ]]; then
        seal_mode="$(stat -c '%a' "$seal" 2>/dev/null || stat -f '%Lp' "$seal" 2>/dev/null || printf 'unknown')"
        [[ "$seal_mode" == "600" ]] || seal_invalid=1
        grep -Fq '"schema":"queuebash.secret_manifest_seal.v1"' "$seal" 2>/dev/null && seal_schema_ok=1 || seal_invalid=1
        grep -Fq '"redacted":true' "$seal" 2>/dev/null && seal_redacted_ok=1 || seal_invalid=1
        grep -Fq '"secret_value_included":false' "$seal" 2>/dev/null && seal_secret_value_marker_ok=1 || seal_invalid=1
        seal_hash="$(sed -n 's/.*"manifest_hash":"\([^"]*\)".*/\1/p' "$seal" | head -n 1)"
        [[ -n "$seal_hash" ]] && seal_hash_present=1 || seal_invalid=1
        seal_manifest_path="$(sed -n 's/.*"manifest":"\([^"]*\)".*/\1/p' "$seal" | head -n 1)"
        [[ "$seal_manifest_path" == "$manifest" ]] && seal_manifest_path_ok=1 || seal_invalid=1
        seal_qid="$(sed -n 's/.*"qid":"\([^"]*\)".*/\1/p' "$seal" | head -n 1)"
        [[ "$seal_qid" == "$qid" ]] && seal_qid_ok=1 || seal_invalid=1
        if [[ "$seal_invalid" -ne 0 ]]; then
            seal_status="invalid"
            malformed_entries=$((malformed_entries + 1))
        elif [[ -n "$seal_hash" && -n "$current_hash" && "$seal_hash" == "$current_hash" ]]; then
            seal_status="match"
        else
            seal_status="mismatch"
            malformed_entries=$((malformed_entries + 1))
        fi
    fi
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        entries=$((entries + 1))
        [[ "$line" == *'"schema":"queuebash.secret_delivery_manifest.v1"'* ]] || malformed_entries=$((malformed_entries + 1))
        [[ "$line" == *'"redacted":true'* ]] || malformed_entries=$((malformed_entries + 1))
        [[ "$line" == *'"secret_value_included":false'* ]] || secret_value_markers=$((secret_value_markers + 1))
        [[ "$line" == *'"secret_ref_hash"'* ]] || malformed_entries=$((malformed_entries + 1))
        [[ "$line" == *'"path_hash"'* ]] || malformed_entries=$((malformed_entries + 1))
        local row_qid="" path_field="" row_secret_ref_hash="" row_path_hash="" computed_path_hash=""
        row_qid="$(printf '%s\n' "$line" | sed -n 's/.*"qid":"\([^"]*\)".*/\1/p' | head -n 1)"
        path_field="$(printf '%s\n' "$line" | sed -n 's/.*"path":"\([^"]*\)".*/\1/p' | head -n 1)"
        row_secret_ref_hash="$(printf '%s\n' "$line" | sed -n 's/.*"secret_ref_hash":"\([^"]*\)".*/\1/p' | head -n 1)"
        row_path_hash="$(printf '%s\n' "$line" | sed -n 's/.*"path_hash":"\([^"]*\)".*/\1/p' | head -n 1)"
        [[ "$row_qid" == "$qid" ]] || qid_mismatches=$((qid_mismatches + 1))
        [[ -n "$row_secret_ref_hash" && -n "$row_path_hash" ]] || missing_hashes=$((missing_hashes + 1))
        if [[ -z "$path_field" ]]; then
            malformed_entries=$((malformed_entries + 1))
            continue
        fi
        computed_path_hash="$(_secret_hash "$path_field" 2>/dev/null || true)"
        [[ -n "$row_path_hash" && "$row_path_hash" == "$computed_path_hash" ]] || path_hash_mismatches=$((path_hash_mismatches + 1))
        case "$path_field" in
            "$target"/*) ;;
            *) unsafe_paths=$((unsafe_paths + 1)) ;;
        esac
        [[ -e "$path_field" ]] || missing_paths=$((missing_paths + 1))
    done < "$manifest"
    if [[ "$entries" -eq 0 || "$insecure_permissions" -ne 0 || "$unsafe_paths" -ne 0 || "$malformed_entries" -ne 0 || "$secret_value_markers" -ne 0 || "$missing_paths" -ne 0 || "$qid_mismatches" -ne 0 || "$missing_hashes" -ne 0 || "$path_hash_mismatches" -ne 0 ]]; then
        ok=false
    fi
    _secret_audit_emit "secret.manifest.verify" "$([[ "$ok" == true ]] && printf ok || printf failed)" "$qid" "" "" "" "" "file" "entries=$entries unsafe_paths=$unsafe_paths missing_paths=$missing_paths qid_mismatches=$qid_mismatches missing_hashes=$missing_hashes path_hash_mismatches=$path_hash_mismatches seal_status=$seal_status"
    if [[ "$json" -eq 1 ]]; then
        printf '{"schema":"queuebash.secret_manifest_verify.v1","ok":%s,"qid":%s,"manifest":%s,"manifest_hash":%s,"seal":%s,"seal_status":%s,"seal_mode":%s,"seal_schema_ok":%s,"seal_redacted_ok":%s,"seal_secret_value_marker_ok":%s,"seal_manifest_path_ok":%s,"seal_qid_ok":%s,"seal_hash_present":%s,"entries":%s,"insecure_permissions":%s,"unsafe_paths":%s,"missing_paths":%s,"malformed_entries":%s,"secret_value_markers":%s,"qid_mismatches":%s,"missing_hashes":%s,"path_hash_mismatches":%s,"redacted":true,"secret_value_included":false}\n' \
            "$ok" "$(_json "$qid")" "$(_json "$manifest")" "$(_json "$current_hash")" "$(_json "$seal")" "$(_json "$seal_status")" "$(_json "$seal_mode")" "$seal_schema_ok" "$seal_redacted_ok" "$seal_secret_value_marker_ok" "$seal_manifest_path_ok" "$seal_qid_ok" "$seal_hash_present" "$entries" "$insecure_permissions" "$unsafe_paths" "$missing_paths" "$malformed_entries" "$secret_value_markers" "$qid_mismatches" "$missing_hashes" "$path_hash_mismatches"
    else
        echo "secret manifest verify: $qid ok=$ok entries=$entries unsafe_paths=$unsafe_paths missing_paths=$missing_paths qid_mismatches=$qid_mismatches missing_hashes=$missing_hashes path_hash_mismatches=$path_hash_mismatches seal_status=$seal_status"
    fi
    [[ "$ok" == true ]]
}

_audit() {
    local json=0 audit_dir audit_log count=0
    while [[ "$#" -gt 0 ]]; do case "$1" in --json|-j) json=1; shift ;; *) echo "file secrets provider audit: unexpected argument: $1" >&2; return 2 ;; esac; done
    audit_dir="$(_secret_audit_dir)"
    audit_log="$audit_dir/secrets_audit.jsonl"
    if [[ -f "$audit_log" ]]; then
        count="$(wc -l < "$audit_log" 2>/dev/null | tr -d ' ' || printf '0')"
    fi
    if [[ "$json" -eq 1 ]]; then
        printf '{"schema":"queuebash.secret_audit.v1","ok":true,"provider":"file","audit_log":%s,"event_count":%s,"secret_value_included":false,"redacted":true}
' "$(_json "$audit_log")" "${count:-0}"
    else
        echo "secret audit: $audit_log events=${count:-0} redacted=true"
    fi
}


main() {
    local sub="${1:-help}"
    shift || true
    case "$sub" in
        help|--help|-h|"") _usage ;;
        explain) _explain "$@" ;;
        request) _request "$@" ;;
        cleanup|revoke) _cleanup "$@" ;;
        seal-manifest|manifest-seal|seal) _secret_manifest_seal "$@" ;;
        verify-manifest|manifest-verify|verify) _secret_manifest_verify "$@" ;;
        audit) _audit "$@" ;;
        *) echo "file secrets provider: unknown subcommand: $sub" >&2; _usage >&2; return 2 ;;
    esac
}
main "$@"
