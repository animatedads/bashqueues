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
    local qid="${1:-}" json=0 run_dir target removed=false
    [[ -n "$qid" ]] || { _usage >&2; return 2; }
    shift || true
    while [[ "$#" -gt 0 ]]; do
        case "$1" in --json|-j) json=1; shift ;; *) echo "file secrets provider cleanup: unexpected argument: $1" >&2; return 2 ;; esac
    done
    [[ "$qid" =~ ^[A-Za-z0-9_.:-]+$ ]] || { _json_error invalid_qid "invalid qid" 2 "$json"; return $?; }
    run_dir="$(_secret_run_dir)"
    target="$run_dir/$qid"
    if [[ -d "$target" ]]; then rm -rf -- "$target"; removed=true; fi
    _secret_audit_emit "secret.cleanup" "ok" "$qid" "" "" "" "" "file" "removed=$removed"
    if [[ "$json" -eq 1 ]]; then
        printf '{"schema":"queuebash.secret_cleanup.v1","ok":true,"qid":%s,"removed":%s,"secret_value_included":false}\n' "$(_json "$qid")" "$removed"
    else
        echo "secret cleanup: $qid removed=$removed"
    fi
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
        audit) _audit "$@" ;;
        *) echo "file secrets provider: unknown subcommand: $sub" >&2; _usage >&2; return 2 ;;
    esac
}
main "$@"
