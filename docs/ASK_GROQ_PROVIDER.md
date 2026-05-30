# Groq ask provider

`queue ask --provider groq` adds a Groq-hosted advisory provider for bashqueues.

The provider is advisory-only. Provider output is data only; it is never evaluated as shell and must not bypass bashqueues policy, ACL, trust, signature, legal, FinOps, or resource controls.

Default endpoint:

```text
https://api.groq.com/openai/v1/chat/completions
```

Default model:

```text
llama-3.3-70b-versatile
```

Groq documents its API as OpenAI-compatible and documents the chat completions endpoint at `/openai/v1/chat/completions`.

## Live use

Default tests do not perform live network calls and do not require credentials. Live use requires explicit enablement:

```bash
QUEUEBASH_AI_LIVE_ENABLED=1 queue ask --provider groq --live --json "How do I inspect queue ask providers?"
```

Credential lookup order:

```text
QUEUEBASH_AI_GROQ_API_KEY_FILE
QUEUEBASH_AI_GROQ_API_KEY
GROQ_API_KEY
```

Useful settings:

```text
QUEUEBASH_AI_GROQ_MODEL
QUEUEBASH_AI_GROQ_ENDPOINT
QUEUEBASH_AI_GROQ_TIMEOUT
QUEUEBASH_AI_GROQ_MAX_OUTPUT_TOKENS
QUEUEBASH_AI_GROQ_TEMPERATURE
```

## Fixture checks

```bash
queue ask provider explain groq --json
queue ask provider test groq --fixture --json
```

## Safety

The provider reads the normalized `queuebash.ai_advisory.request.v1` request and returns `queuebash.ai_advisory.response.v1`. It redacts API-key-shaped values in error details, bounds context reads, and reports provider failures as data.
