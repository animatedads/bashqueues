#!/usr/bin/env bash
# queuebash secrets provider broker (fixture-first contract)
set -euo pipefail

_secrets_here() { cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P; }
_secrets_json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.argv[1])[1:-1])' "${1:-}"; }
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

Default delivery is file-based. Provider responses must never include secret values.
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

main() {
    local sub="${1:-help}"
    shift || true
    case "$sub" in
        help|--help|-h|"") _secrets_usage ;;
        providers|list-providers) _secrets_providers "$@" ;;
        explain) _secrets_forward explain "$@" ;;
        request) _secrets_forward request "$@" ;;
        cleanup|revoke) _secrets_forward cleanup "$@" ;;
        audit) _secrets_forward audit "$@" ;;
        *) echo "queue secrets: unknown subcommand: $sub" >&2; _secrets_usage >&2; return 2 ;;
    esac
}
main "$@"
