#!/usr/bin/env bash
# OpenAI-compatible local/private ask provider descriptor for bashqueues queue ask.
set -euo pipefail
case "${1:-}" in
  describe|--describe)
    cat <<'JSON'
{"schema":"queuebash.ask_provider.contract.v1","provider":"openai_compat","live_supported":true,"fixture_supported":true,"requires_network":false,"advisory_only":true,"helper":"queue-ai-ask-openai-compat","endpoint_family":"openai_chat_completions_compatible"}
JSON
    ;;
  *)
    echo "queuebash ask provider openai_compat helper: describe only" >&2
    exit 2
    ;;
esac
