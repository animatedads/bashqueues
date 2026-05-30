# Cerebras ask provider

`queue ask --provider cerebras` adds a Bob11 ask-provider adapter for Cerebras Inference.

The provider is advisory-only. Provider output is data only; bashqueues never evaluates provider output as shell.

## Default configuration

```sh
QUEUEBASH_AI_CEREBRAS_ENDPOINT=https://api.cerebras.ai/v1/chat/completions
QUEUEBASH_AI_CEREBRAS_MODEL=gpt-oss-120b
QUEUEBASH_AI_CEREBRAS_TIMEOUT=60
QUEUEBASH_AI_CEREBRAS_MAX_OUTPUT_TOKENS=4096
QUEUEBASH_AI_CEREBRAS_TEMPERATURE=0.2
```

Cerebras documents OpenAI compatibility with base URL `https://api.cerebras.ai/v1`, so this helper targets the chat completions endpoint under that base URL.

## Credentials

Credential lookup order:

```text
QUEUEBASH_AI_CEREBRAS_API_KEY_FILE
QUEUEBASH_AI_CEREBRAS_API_KEY
CEREBRAS_API_KEY
```

Use a key file where possible. Do not place API keys in shell history, scratchpad entries, examples, committed policies, or logs.

## Fixture and live use

Fixture discovery does not require credentials or network access:

```sh
queue ask provider explain cerebras --json
queue ask provider test cerebras --fixture --json
```

Live use requires explicit live enablement and a configured credential:

```sh
QUEUEBASH_AI_LIVE_ENABLED=1 queue ask --provider cerebras --live --json "How do I inspect queue ask providers?"
```

## Safety model

The helper receives a normalized `queuebash.ai_advisory.request.v1` request, performs a bounded chat-completions call only when queuebash has already allowed live mode, redacts provider errors, and returns normalized advisory JSON. It does not execute commands, bypass policy, or mutate queue state.
