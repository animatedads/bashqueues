# Ask Anthropic provider

`0.18.44` adds an optional Anthropic live provider for `queue ask`.

The provider is advisory-only. It translates the normalized bashqueues ask request
into an Anthropic Messages API request through `bin/queue-ai-ask-anthropic`, then
translates the provider response back into `queuebash.ai_advisory.response.v1`.
Provider output is data only and is never evaluated as shell.

Default tests do not perform a live Anthropic API call, do not require network,
and do not require credentials. Live use requires explicit policy enablement:

```bash
QUEUEBASH_AI_LIVE_ENABLED=1 queue ask --provider anthropic --live --json "How do I inspect queue ask providers?"
```

## Helper and descriptor

```text
bin/queue-ai-ask-anthropic
providers.d/ask/anthropic.sh
```

The queue dispatcher only selects the provider helper, applies policy/audit gates,
and writes the normalized request. Anthropic-specific API headers, payload shape,
response parsing, timeout handling, and secret redaction live in the helper.

## Key lookup order

```text
QUEUEBASH_AI_ANTHROPIC_API_KEY_FILE
QUEUEBASH_AI_ANTHROPIC_API_KEY
ANTHROPIC_API_KEY
```

Prefer the file form for service installs. Do not pass API keys on the command
line and do not place real keys in docs, examples, scratchpad notes, logs, or
package zips.

## Configuration

```text
QUEUEBASH_AI_ANTHROPIC_MODEL=claude-sonnet-4-20250514
QUEUEBASH_AI_ANTHROPIC_ENDPOINT=https://api.anthropic.com/v1/messages
QUEUEBASH_AI_ANTHROPIC_VERSION=2023-06-01
QUEUEBASH_AI_ANTHROPIC_TIMEOUT=60
QUEUEBASH_AI_ANTHROPIC_MAX_OUTPUT_TOKENS=4096
QUEUEBASH_AI_ANTHROPIC_TEMPERATURE=0.2
```

## Fixture/default testing

```bash
queue ask provider explain anthropic --json
queue ask provider test anthropic --fixture --json
```

The smoke test proves that the live path is blocked without
`QUEUEBASH_AI_LIVE_ENABLED=1` and that the helper fails closed before network when
no Anthropic key is configured.

## Security posture

- Live provider use is opt-in.
- Default tests are fixture/gated only.
- Request context is bounded and redacted before helper invocation.
- Provider output is advisory data, never shell.
- Errors redact API-key-like values before writing normalized JSON.
- Audit reason for successful live calls is `live_anthropic_provider`.
