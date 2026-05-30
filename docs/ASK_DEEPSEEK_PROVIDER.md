# DeepSeek ask provider

`0.18.55` adds a Bob11 DeepSeek provider for `queue ask`. It is advisory-only, fixture/gated by default, and performs no live network call unless `QUEUEBASH_AI_LIVE_ENABLED=1` is set and a DeepSeek API key is supplied.

## Commands

```bash
queue ask provider explain deepseek --json
queue ask provider test deepseek --fixture --json
QUEUEBASH_AI_LIVE_ENABLED=1 queue ask --provider deepseek --live --json "question"
```

## Configuration

```bash
QUEUEBASH_AI_DEEPSEEK_ENDPOINT=https://api.deepseek.com/chat/completions
QUEUEBASH_AI_DEEPSEEK_MODEL=deepseek-v4-flash
QUEUEBASH_AI_DEEPSEEK_TIMEOUT=60
QUEUEBASH_AI_DEEPSEEK_MAX_OUTPUT_TOKENS=4096
QUEUEBASH_AI_DEEPSEEK_TEMPERATURE=0.2
```

Key lookup order:

```text
QUEUEBASH_AI_DEEPSEEK_API_KEY_FILE
QUEUEBASH_AI_DEEPSEEK_API_KEY
DEEPSEEK_API_KEY
```

## Safety contract

The provider helper receives a normalized queuebash advisory request, builds bounded/redacted context, calls DeepSeek only in live mode, and returns normalized `queuebash.ai_advisory.response.v1` JSON. Provider output is data only and is never executed as shell.

Default tests use fixture mode only and require no key, no credentials, and no live DeepSeek API call.
