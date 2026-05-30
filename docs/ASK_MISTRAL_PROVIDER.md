# Mistral AI ask provider

`queue ask --provider mistral` lets bashqueues use Mistral AI as a live
advisory provider while keeping the same policy, context, audit, and
advisory-only model as the other ask providers.

The provider targets Mistral's chat completions API endpoint family at
`/v1/chat/completions`. Default tests are fixture/gated only and do not call
Mistral, require a network connection, or require an API key.

## Command surface

```bash
queue ask provider explain mistral --json
queue ask provider test mistral --fixture --json
QUEUEBASH_AI_LIVE_ENABLED=1 queue ask --provider mistral --live --json "How do I list providers?"
```

## Configuration

```bash
export QUEUEBASH_AI_MISTRAL_ENDPOINT="https://api.mistral.ai/v1/chat/completions"
export QUEUEBASH_AI_MISTRAL_MODEL="mistral-small-latest"
export QUEUEBASH_AI_MISTRAL_API_KEY_FILE="/etc/bashqueues/secrets/mistral.key"
```

Key lookup order:

```text
QUEUEBASH_AI_MISTRAL_API_KEY_FILE
QUEUEBASH_AI_MISTRAL_API_KEY
MISTRAL_API_KEY
```

Live use requires both `QUEUEBASH_AI_LIVE_ENABLED=1` and an API key. API keys
must not be placed in command lines, scratchpad notes, logs, examples, or
package zips. Prefer the `*_API_KEY_FILE` setting.

## Safety model

Provider output is data, never shell. `queue ask` applies policy gates, context
redaction, live-mode gating, audit logging, and advisory-only handling before
invoking the helper. The helper returns normalized
`queuebash.ai_advisory.response.v1` JSON and never executes model output.
