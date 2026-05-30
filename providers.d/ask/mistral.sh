#!/usr/bin/env bash
# Mistral AI ask provider descriptor for bashqueues queue ask.
set -euo pipefail
case "${1:-}" in
  describe|--describe)
    cat <<'JSON'
{"schema":"queuebash.ask_provider.contract.v1","provider":"mistral","live_supported":true,"fixture_supported":true,"requires_network":true,"advisory_only":true,"helper":"queue-ai-ask-mistral","endpoint_family":"mistral_chat_completions"}
JSON
    ;;
  *)
    echo "queuebash ask provider mistral helper: describe only" >&2
    exit 2
    ;;
esac
