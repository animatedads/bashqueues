#!/usr/bin/env bash
# Perplexity Sonar ask-provider descriptor for queue ask.
# Live calls are performed by bin/queue-ai-ask-perplexity only when queuebash
# has already allowed QUEUEBASH_AI_LIVE_ENABLED=1.

queue_ask_provider_name() { printf '%s\n' perplexity; }
queue_ask_provider_helper() { printf '%s\n' queue-ai-ask-perplexity; }
queue_ask_provider_live_supported() { printf '%s\n' true; }
queue_ask_provider_fixture_supported() { printf '%s\n' true; }
queue_ask_provider_requires_network() { printf '%s\n' true; }
queue_ask_provider_default_model() { printf '%s\n' "${QUEUEBASH_AI_PERPLEXITY_MODEL:-sonar-pro}"; }
queue_ask_provider_endpoint_family() { printf '%s\n' perplexity_sonar_openai_chat_completions; }

if [[ "${1:-}" == "--describe" ]]; then
  printf '{"schema":"queuebash.ask_provider.contract.v1","provider":"perplexity","live_supported":true,"fixture_supported":true,"requires_network":true,"advisory_only":true,"default_model":"%s","endpoint_family":"perplexity_sonar_openai_chat_completions"}\n' "$(queue_ask_provider_default_model)"
fi
