#!/usr/bin/env bash
# Baseten Model APIs ask-provider descriptor for queue ask.
# Live calls are performed by bin/queue-ai-ask-baseten only when queuebash
# has already allowed QUEUEBASH_AI_LIVE_ENABLED=1.

queue_ask_provider_name() { printf '%s
' baseten; }
queue_ask_provider_helper() { printf '%s
' queue-ai-ask-baseten; }
queue_ask_provider_live_supported() { printf '%s
' true; }
queue_ask_provider_fixture_supported() { printf '%s
' true; }
queue_ask_provider_requires_network() { printf '%s
' true; }
queue_ask_provider_default_model() { printf '%s
' "${QUEUEBASH_AI_BASETEN_MODEL:-deepseek-ai/DeepSeek-V4-Pro}"; }
queue_ask_provider_endpoint_family() { printf '%s
' baseten_model_apis_openai_chat_completions; }

if [[ "${1:-}" == "--describe" ]]; then
  printf '{"schema":"queuebash.ask_provider.contract.v1","provider":"baseten","live_supported":true,"fixture_supported":true,"requires_network":true,"advisory_only":true,"default_model":"%s","endpoint_family":"baseten_model_apis_openai_chat_completions"}
' "$(queue_ask_provider_default_model)"
fi
