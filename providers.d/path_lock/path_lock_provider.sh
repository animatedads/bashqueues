#!/usr/bin/env bash
# queuebash path-lock provider facade. Fixture-only: no path opens or writes.
set -euo pipefail

_provider_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_fixture="${_provider_dir}/path_lock_fixture.py"

_json_escape() {
  local s=${1-}
  s=${s//\\/\\\\}; s=${s//\"/\\\"}; s=${s//$'\n'/\\n}; s=${s//$'\r'/\\r}; s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

case "${1-}" in
  evaluate)
    shift || true
    fixture=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --fixture) fixture="${2-}"; shift 2 ;;
        --json) shift ;;
        *) fixture="$1"; shift ;;
      esac
    done
    if [[ -z "$fixture" || ! -f "$fixture" ]]; then
      printf '{"schema":"queuebash.path_lock.decision.v1","status":"blocked","allowed":false,"reasons":["fixture_missing"],"redacted":true,"secret_value_included":false}\n'
      exit 1
    fi
    exec python3 "$_fixture" evaluate "$fixture"
    ;;
  explain|--help|-h|help|'')
    cat <<'EOF'
Usage: path_lock_provider.sh evaluate --fixture FIXTURE.json --json

Fixture-only path-lock evaluator. It does not open, write, chmod, chown,
rename, delete, or inspect live target paths. Runtime enforcement must use a
future safe-open implementation bound to trusted parent directory/object
identity.
EOF
    ;;
  *)
    printf '{"schema":"queuebash.path_lock.decision.v1","status":"blocked","allowed":false,"reasons":["unknown_command"],"redacted":true,"secret_value_included":false,"command":"%s"}\n' "$(_json_escape "$1")"
    exit 2
    ;;
esac
