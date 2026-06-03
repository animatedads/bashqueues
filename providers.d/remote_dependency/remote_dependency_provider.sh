#!/usr/bin/env bash
# Provider-neutral remote dependency resolver wrapper.
# The default implementation is fixture-only and read-only.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  remote_dependency_provider.sh resolve REQUEST_JSON [--json]
  remote_dependency_provider.sh explain REQUEST_JSON [--json]

REQUEST_JSON may be a path to a JSON request or a JSON string with schema
queuebash.remote_dependency.request.v1. The fixture provider returns redacted
queuebash.remote_dependency.v1 evidence and never performs SSH, arbitrary shell,
remote mutation, or unauthenticated HTTP polling.
EOF
}

cmd="${1:-}"
case "$cmd" in
  resolve|explain) shift ;;
  -h|--help|help|"") usage; exit 0 ;;
  *) echo "remote_dependency_provider.sh: unknown command: $cmd" >&2; usage >&2; exit 2 ;;
esac

request="${1:-}"
[[ -n "$request" ]] || { echo "remote_dependency_provider.sh: REQUEST_JSON is required" >&2; exit 2; }
shift || true
json=0
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --json|-j) json=1; shift ;;
    *) echo "remote_dependency_provider.sh: unexpected argument: $1" >&2; exit 2 ;;
  esac
done

here="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
fixture="${QUEUEBASH_REMOTE_DEPENDENCY_FIXTURE_HELPER:-$here/remote_dependency_fixture.py}"
exec python3 "$fixture" "$cmd" "$request" --json
