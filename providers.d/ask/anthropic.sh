#!/usr/bin/env bash
# Anthropic ask provider descriptor for bashqueues queue ask.
# Live execution is performed by bin/queue-ai-ask-anthropic after queuebash.sh has
# applied policy gates, context redaction, audit setup, and live-mode checks.
set -euo pipefail
case "${1:-}" in
  describe|--describe)
    cat <<'JSON'
{"schema":"queuebash.ask_provider.contract.v1","provider":"anthropic","live_supported":true,"fixture_supported":true,"requires_network":true,"advisory_only":true,"helper":"queue-ai-ask-anthropic"}
JSON
    ;;
  *)
    echo "queuebash ask provider anthropic helper: describe only" >&2
    exit 2
    ;;
esac
