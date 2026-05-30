# OpenAI-compatible local/private ask provider

`queue ask --provider openai_compat` lets bashqueues use a local or private
OpenAI-compatible chat-completions endpoint while keeping the same advisory,
policy, context, and audit model as the cloud providers.

Typical endpoint families include local/private gateways that implement an
OpenAI-style `/v1/chat/completions` API, such as a local model server, an
internal inference gateway, or an enterprise proxy. This provider is intended
for controlled endpoints; it does not make default tests depend on any live
server, model, network, or credentials.

## Command surface

```bash
queue ask provider explain openai_compat --json
queue ask provider test openai_compat --fixture --json
QUEUEBASH_AI_LIVE_ENABLED=1 queue ask --provider openai_compat --live --json "How do I list providers?"
```

## Configuration

```bash
export QUEUEBASH_AI_OPENAI_COMPAT_ENDPOINT="http://127.0.0.1:8000/v1/chat/completions"
export QUEUEBASH_AI_OPENAI_COMPAT_MODEL="local-model"
# Optional for private gateways that require bearer auth:
export QUEUEBASH_AI_OPENAI_COMPAT_API_KEY_FILE="/etc/bashqueues/secrets/openai_compat.key"
```

Key lookup order:

```text
QUEUEBASH_AI_OPENAI_COMPAT_API_KEY_FILE
QUEUEBASH_AI_OPENAI_COMPAT_API_KEY
OPENAI_COMPAT_API_KEY
```

No key is required by the helper when the endpoint permits unauthenticated
loopback/local access.

## Safety model

Provider output is data, never shell. `queue ask` applies policy gates,
context redaction, live-mode gating, audit logging, and advisory-only handling
before invoking the helper. The helper returns normalized
`queuebash.ai_advisory.response.v1` JSON and never executes model output.

Default tests are fixture/gated only and perform no live HTTP request.
