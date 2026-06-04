#!/usr/bin/env bash
# queuebash secrets provider broker (fixture-first contract)
set -euo pipefail

_secrets_here() { cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P; }
_secrets_json_escape() {
    local s="${1:-}"
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    s=${s//$'\r'/\\r}
    s=${s//$'\t'/\\t}
    printf '%s' "$s"
}
_secrets_json_quote() { printf '"%s"' "$(_secrets_json_escape "${1:-}")"; }
_secrets_json_error() {
    local code="${1:-error}" message="${2:-secrets broker error}" rc="${3:-1}"
    printf '{"schema":"queuebash.error.v1","ok":false,"error":{"code":%s,"message":%s,"rc":%s}}\n' "$(_secrets_json_quote "$code")" "$(_secrets_json_quote "$message")" "$rc"
    return "$rc"
}
_secrets_file_provider() {
    local here cand
    here="$(_secrets_here)"
    for cand in \
        "$here/file_provider.sh" \
        "$here/../secrets/file_provider.sh" \
        "/usr/local/share/bashqueues/providers.d/secrets/file_provider.sh" \
        "$HOME/.queuebash/providers.d/secrets/file_provider.sh"; do
        [[ -f "$cand" ]] && { printf '%s\n' "$cand"; return 0; }
    done
    return 1
}

_secrets_usage() {
    cat <<'USAGE'
queue secrets - governed secret access broker

Usage:
  queue secrets providers [--json]
  queue secrets explain SECRET_REF --class CLASS [--json]
  queue secrets request SECRET_REF --name NAME --class CLASS --purpose TEXT --qid QID [--delivery file] [--ttl-seconds N] [--max-runtime-seconds N] [--json]
  queue secrets cleanup QID [--json]
  queue secrets seal-manifest QID [--json]
  queue secrets verify-manifest QID [--json]
  queue secrets audit [--json]
  queue secrets break-glass request SECRET_REF --reason TEXT --ticket ID [--json]
  queue secrets break-glass approve REQUEST_ID --authorisation CODE [--json]
  queue secrets break-glass deliver REQUEST_ID --delivery file [--json]

Default delivery is file-based. Provider responses must never include secret values.
Break-glass is refused by default in the fixture broker unless a future signed
provider implements the dual-control workflow.
USAGE
}

_secrets_providers() {
    local json=0
    while [[ "$#" -gt 0 ]]; do
        case "$1" in --json|-j) json=1; shift ;; *) echo "queue secrets providers: unexpected argument: $1" >&2; return 2 ;; esac
    done
    if [[ "$json" -eq 1 ]]; then
        printf '{"schema":"queuebash.secrets.providers.v1","providers":[{"name":"file","kind":"fixture","default_delivery":"file","live":false}],"default_provider":"file"}\n'
    else
        echo "Secrets providers"
        echo "  file    fixture/dev file-backed provider (delivery: file, live: no)"
    fi
}

_secrets_forward() {
    local helper
    helper="$(_secrets_file_provider)" || { echo "queue secrets: helper not found: providers.d/secrets/file_provider.sh" >&2; return 1; }
    bash "$helper" "$@"
}

_secrets_break_glass() {
    local action="${1:-}" json=0
    shift || true
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --json|-j) json=1; shift ;;
            --*) shift 2 2>/dev/null || shift || true ;;
            *) shift ;;
        esac
    done
    case "$action" in
        request|approve|deliver) ;;
        *) echo "queue secrets break-glass: expected request, approve, or deliver" >&2; return 2 ;;
    esac
    if [[ "$json" -eq 1 ]]; then
        printf '{"schema":"queuebash.secrets.break_glass.v1","ok":false,"action":%s,"status":"denied","error":{"code":"authorization_required","message":"break-glass secrets access requires a signed dual-control provider; fixture broker refuses by default"},"secret_value_included":false}\n' "$(_secrets_json_quote "$action")"
    else
        echo "queue secrets break-glass: denied - signed dual-control provider required" >&2
    fi
    return 4
}

main() {
    local sub="${1:-help}"
    shift || true
    case "$sub" in
        help|--help|-h|"") _secrets_usage ;;
        providers|list-providers) _secrets_providers "$@" ;;
        explain) _secrets_forward explain "$@" ;;
        request) _secrets_forward request "$@" ;;
        cleanup|revoke) _secrets_forward cleanup "$@" ;;
        seal-manifest|manifest-seal|seal) _secrets_forward seal-manifest "$@" ;;
        verify-manifest|manifest-verify|verify) _secrets_forward verify-manifest "$@" ;;
        audit) _secrets_forward audit "$@" ;;
        break-glass|breakglass) _secrets_break_glass "$@" ;;
        *) echo "queue secrets: unknown subcommand: $sub" >&2; _secrets_usage >&2; return 2 ;;
    esac
}
main "$@"
