# queue ask OpenAI provider

This package adds an optional OpenAI live provider for `queue ask`.

The provider is advisory-only. `queuebash.sh` performs policy checks, context
selection, redaction, safety classification, and audit setup before invoking the
helper. The helper translates the normalized `queuebash.ai_advisory.request.v1`
request into an OpenAI Responses API call and returns normalized
`queuebash.ai_advisory.response.v1` JSON.

## Usage

```text
QUEUEBASH_AI_LIVE_ENABLED=1 queue ask --provider openai --live --json "question"
```

Default tests do not require live API access, network access, or credentials.

## Key lookup

The helper looks for credentials in this order:

```text
QUEUEBASH_AI_OPENAI_API_KEY_FILE
QUEUEBASH_AI_OPENAI_API_KEY
OPENAI_API_KEY
```

Prefer `QUEUEBASH_AI_OPENAI_API_KEY_FILE`. API keys must not appear in command
lines, scratchpad notes, logs, example files, or package zips.

## Configuration

```text
QUEUEBASH_AI_OPENAI_MODEL=gpt-4.1-mini
QUEUEBASH_AI_OPENAI_ENDPOINT=https://api.openai.com/v1/responses
QUEUEBASH_AI_OPENAI_TIMEOUT=60
QUEUEBASH_AI_OPENAI_MAX_OUTPUT_TOKENS=4096
QUEUEBASH_AI_OPENAI_TEMPERATURE=0.2
```

## Failure handling

The provider fails closed. Missing credentials, timeout, unreachable endpoint,
HTTP errors, invalid JSON, and empty responses return bounded normalized error
JSON. HTTP error details are redacted before being surfaced to `queue ask`.

Provider output remains data only and is never evaluated as shell.
