#!/usr/bin/env bash
# queuebash optional AI policy gate provider: local Ollama only.
# This mirrors the ask-provider shape but is deliberately narrower:
# it receives a bounded local job-risk request and returns a normalized JSON
# decision. It must not execute model output and must not send data off-host.
set -euo pipefail

case "${1:-}" in
  describe|--describe)
    cat <<'JSON'
{"schema":"queuebash.ai_policy_gate.provider.v1","provider":"ollama","live_supported":true,"fixture_supported":true,"local_only":true,"decision_schema":"queuebash.ai_policy_gate.decision.v1","default_model_env":"QUEUEBASH_AI_MODEL"}
JSON
    ;;
  classify)
    shift
    exec "${QUEUEBASH_AI_POLICY_GATE_HELPER:-queue-ai-policy-gate}" classify --provider ollama "$@"
    ;;
  *)
    echo "queuebash ai policy gate ollama provider: use describe or classify" >&2
    exit 2
    ;;
esac
