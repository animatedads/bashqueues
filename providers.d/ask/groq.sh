#!/usr/bin/env bash
# Groq ask provider descriptor for bashqueues queue ask.
set -euo pipefail
case "${1:-}" in
  describe|--describe)
    cat <<'JSON'
{"schema":"queuebash.ask_provider.contract.v1","provider":"groq","live_supported":true,"fixture_supported":true,"requires_network":true,"advisory_only":true,"helper":"queue-ai-ask-groq","endpoint_family":"groq_openai_chat_completions"}
JSON
    ;;
  *)
    echo "queuebash ask provider groq helper: describe only" >&2
    exit 2
    ;;
esac
