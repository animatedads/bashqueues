#!/usr/bin/env bash
# DeepSeek ask provider descriptor for bashqueues queue ask.
set -euo pipefail
case "${1:-}" in
  describe|--describe)
    cat <<'JSON'
{"schema":"queuebash.ask_provider.contract.v1","provider":"deepseek","live_supported":true,"fixture_supported":true,"requires_network":true,"advisory_only":true,"helper":"queue-ai-ask-deepseek","endpoint_family":"deepseek_openai_chat_completions"}
JSON
    ;;
  *)
    echo "queuebash ask provider deepseek helper: describe only" >&2
    exit 2
    ;;
esac
