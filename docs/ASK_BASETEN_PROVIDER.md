# Baseten ask provider

The Baseten ask provider adds Baseten Model APIs coverage to `queue ask` and the
AI broker. It is advisory-only: Provider output is data only and is never
evaluated as shell.

## Endpoint family

Baseten Model APIs expose OpenAI-compatible chat completions at:

```text
https://inference.baseten.co/v1/chat/completions
```

The default model in this package follows Baseten's public Model APIs example:

```text
deepseek-ai/DeepSeek-V4-Pro
```

Custom Baseten deployments can also expose OpenAI-compatible endpoints under a
model-specific URL such as:

```text
https://model-{model_id}.api.baseten.co/environments/production/sync/v1/chat/completions
```

Override `QUEUEBASH_AI_BASETEN_ENDPOINT` for those deployments and
`QUEUEBASH_AI_BASETEN_MODEL` for the served model name.

## Live use

Default tests do not call Baseten and require no credentials. Live use requires
all of the following:

```sh
QUEUEBASH_AI_LIVE_ENABLED=1
QUEUEBASH_AI_BASETEN_API_KEY_FILE=/path/to/baseten-api-key
# or QUEUEBASH_AI_BASETEN_API_KEY / BASETEN_API_KEY
```

Example:

```sh
QUEUEBASH_AI_LIVE_ENABLED=1 QUEUEBASH_AI_BASETEN_API_KEY_FILE=/run/secrets/baseten.key queue ask --provider baseten --live --json "summarise queue ask provider support"
```

## Configuration

```sh
QUEUEBASH_AI_BASETEN_MODEL="deepseek-ai/DeepSeek-V4-Pro"
QUEUEBASH_AI_BASETEN_ENDPOINT="https://inference.baseten.co/v1/chat/completions"
QUEUEBASH_AI_BASETEN_TIMEOUT=60
QUEUEBASH_AI_BASETEN_MAX_OUTPUT_TOKENS=4096
QUEUEBASH_AI_BASETEN_TEMPERATURE=0.2
```

Credential lookup order:

```text
QUEUEBASH_AI_BASETEN_API_KEY_FILE
QUEUEBASH_AI_BASETEN_API_KEY
BASETEN_API_KEY
```

## Safety posture

- Live calls are blocked unless `QUEUEBASH_AI_LIVE_ENABLED=1` is set.
- API keys must not be placed in command lines, logs, examples, scratchpad notes,
  or package zips.
- The helper performs bounded context reads and skips files that look like they
  contain secrets.
- HTTP error details are redacted before being returned.
- Provider output is advisory data only and is never evaluated as shell.
