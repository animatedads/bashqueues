#!/usr/bin/env bash
# queuebash fixture file-backed secrets provider.
# It is for dev/test contracts and never performs live cloud/Vault calls.
set -euo pipefail

_json() {
    python3 - "$@" <<'PYJSON'
import json, sys
print(json.dumps(sys.argv[1]))
PYJSON
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
_secret_run_dir() {
    if [[ -n "${QUEUEBASH_SECRET_RUN_DIR:-}" ]]; then
        printf '%s\n' "$QUEUEBASH_SECRET_RUN_DIR"
    elif [[ -n "${QUEUEBASH_ROOT:-}" ]]; then
        printf '%s\n' "$QUEUEBASH_ROOT/secrets/run"
    else
        printf '%s\n' "$HOME/.queuebash/secrets/run"
    fi
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
    file_name="$(_secret_ref_to_file_name "$secret_ref" 2>/dev/null)" || { _json_error invalid_secret_ref "invalid secret reference" 2 "$json"; return $?; }
    fixture_dir="$(_secret_fixture_dir)"
    src="$fixture_dir/$file_name"
    [[ -f "$src" ]] || { _json_error not_found "fixture secret not found" 4 "$json"; return $?; }
    run_dir="$(_secret_run_dir)"
    dest_dir="$run_dir/$qid"
    dest="$dest_dir/$name"
    mkdir -p -- "$dest_dir"
    chmod 700 -- "$dest_dir" 2>/dev/null || true
    umask 077
    # Copy exactly, without echoing the secret to stdout/stderr.
    cat -- "$src" > "$dest"
    chmod 600 -- "$dest"
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
    if [[ "$json" -eq 1 ]]; then
        printf '{"schema":"queuebash.secret_cleanup.v1","ok":true,"qid":%s,"removed":%s,"secret_value_included":false}\n' "$(_json "$qid")" "$removed"
    else
        echo "secret cleanup: $qid removed=$removed"
    fi
}

_audit() {
    local json=0
    while [[ "$#" -gt 0 ]]; do case "$1" in --json|-j) json=1; shift ;; *) echo "file secrets provider audit: unexpected argument: $1" >&2; return 2 ;; esac; done
    if [[ "$json" -eq 1 ]]; then
        printf '{"schema":"queuebash.secret_audit.v1","ok":true,"provider":"file","events":[],"secret_value_included":false}\n'
    else
        echo "secret audit: fixture provider has no persistent audit log in contract-first mode"
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
