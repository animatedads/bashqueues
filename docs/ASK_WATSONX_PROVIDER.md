# IBM watsonx.ai ask provider

`queue ask --provider watsonx` adds an IBM watsonx.ai live-provider pack to the bashqueues ask-provider socket.

The provider is advisory only. It never executes model output, never shells model text, and remains blocked unless live AI is explicitly enabled.

## Default behaviour

Default tests are fixture/gated only. They do not call IBM Cloud, require credentials, or require a watsonx project.

Live use requires all of the following:

```bash
export QUEUEBASH_AI_LIVE_ENABLED=1
export QUEUEBASH_AI_WATSONX_PROJECT_ID="..."
export QUEUEBASH_AI_WATSONX_API_KEY_FILE=/path/to/ibm-cloud-api-key
queue ask --provider watsonx --live --json "How do I inspect queue ask providers?"
```

A pre-created bearer token may be used instead of an API key:

```bash
export QUEUEBASH_AI_WATSONX_BEARER_TOKEN_FILE=/path/to/token
```

## Configuration

```bash
QUEUEBASH_AI_WATSONX_MODEL=ibm/granite-3-8b-instruct
QUEUEBASH_AI_WATSONX_ENDPOINT=https://us-south.ml.cloud.ibm.com/ml/v1/text/generation
QUEUEBASH_AI_WATSONX_VERSION=2025-02-11
QUEUEBASH_AI_WATSONX_PROJECT_ID=...
QUEUEBASH_AI_WATSONX_TIMEOUT=60
QUEUEBASH_AI_WATSONX_MAX_NEW_TOKENS=4096
QUEUEBASH_AI_WATSONX_TEMPERATURE=0.2
```

The helper calls the IBM watsonx.ai text generation endpoint shape:

```text
POST /ml/v1/text/generation?version=YYYY-MM-DD
Authorization: Bearer TOKEN
Content-Type: application/json
```

Request body fields are `model_id`, `input`, `parameters`, and `project_id`.

## Credential lookup

The helper resolves credentials in this order:

1. `QUEUEBASH_AI_WATSONX_BEARER_TOKEN_FILE`
2. `QUEUEBASH_AI_WATSONX_BEARER_TOKEN`
3. `WATSONX_BEARER_TOKEN`
4. `QUEUEBASH_AI_WATSONX_API_KEY_FILE`
5. `QUEUEBASH_AI_WATSONX_API_KEY`
6. `IBM_CLOUD_API_KEY`

API keys are exchanged for an IBM Cloud IAM access token using the configured IAM token endpoint. Tokens and keys are redacted from error strings and normalized response JSON.

## Safety contract

- Provider output is data, never shell.
- No live network call occurs unless the user passes `--live` and `QUEUEBASH_AI_LIVE_ENABLED=1` is set.
- Default tests assert discovery, fixture test, live gate denial, and fail-closed missing credential/project handling.
- API keys must not be placed in examples, scratchpad notes, command lines, logs, or committed policy files.
