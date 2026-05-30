# Perplexity Sonar ask provider

`queue ask --provider perplexity` adds a fixture-gated live provider for Perplexity's Sonar API.

The provider is advisory-only. The model response is written as data and is never evaluated as shell, never treated as approval, and never bypasses queuebash policy, ACL, trust, legal, FinOps, or safety gates.

## Commands

```bash
queue ask provider explain perplexity --json
queue ask provider test perplexity --fixture --json
QUEUEBASH_AI_LIVE_ENABLED=1 queue ask --provider perplexity --live --json "How do I inspect providers?"
```

## Configuration

```bash
QUEUEBASH_AI_PERPLEXITY_MODEL=sonar-pro
QUEUEBASH_AI_PERPLEXITY_ENDPOINT=https://api.perplexity.ai/chat/completions
QUEUEBASH_AI_PERPLEXITY_API_KEY_FILE=/etc/bashqueues/secrets/perplexity-api-key
```

Key lookup order:

```text
QUEUEBASH_AI_PERPLEXITY_API_KEY_FILE
QUEUEBASH_AI_PERPLEXITY_API_KEY
PERPLEXITY_API_KEY
```

## Default test posture

Default tests are fixture/gated. They must not require a Perplexity API key, live network access, or an API account.

## Endpoint family

This provider uses an OpenAI-compatible chat-completions request/response shape against the Perplexity Sonar API endpoint. The default model is `sonar-pro`.
