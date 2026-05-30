#!/usr/bin/env bash
# queuebash ask provider contract helper notes.
# Providers translate normalized queuebash.ask_context_bundle.v1 input into a
# provider-specific request and return queuebash.ask_provider.response.v1 JSON.
set -euo pipefail
case "${1:-}" in
  describe|--describe)
    cat <<'JSON'
{"schema":"queuebash.ask_provider.contract.v1","provider":"contract","live_supported":false,"fixture_supported":true,"advisory_only":true}
JSON
    ;;
  *)
    echo "queuebash ask provider contract helper: describe only" >&2
    exit 2
    ;;
esac
