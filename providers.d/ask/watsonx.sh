#!/usr/bin/env bash
# IBM watsonx.ai ask provider descriptor for bashqueues queue ask.
# Live execution is performed by bin/queue-ai-ask-watsonx after queuebash.sh has
# applied policy gates, context redaction, audit setup, and live-mode checks.
set -euo pipefail
case "${1:-}" in
  describe|--describe)
    cat <<'JSON'
{"schema":"queuebash.ask_provider.contract.v1","provider":"watsonx","live_supported":true,"fixture_supported":true,"requires_network":true,"advisory_only":true,"helper":"queue-ai-ask-watsonx"}
JSON
    ;;
  *)
    echo "queuebash ask provider watsonx helper: describe only" >&2
    exit 2
    ;;
esac
