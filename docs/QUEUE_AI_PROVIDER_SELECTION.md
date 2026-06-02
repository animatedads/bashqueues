# queue AI provider selection and fallback

Provider selection is a policy decision, not a hard-coded model string.

## Capability matrix

Supported capability names begin with:

```text
chat
completion
summarize
classify
json
schema_json
tool_calling
vision
audio
embedding
code
long_context
local
cloud
streaming
batch
low_cost
high_quality
fast
```

Provider/model entries can include more capabilities, but tests should keep these names stable.

## Scoring inputs

A provider/model candidate is scored using:

```text
profile provider order
capability match
health state
cost ceiling
latency ceiling
privacy/locality constraints
quality preference
fallback policy
explicit pin/no-fallback flags
```

Hard constraints eliminate candidates. Soft preferences rank remaining candidates.

## Fallback result

When fallback is used, responses must tell the job and audit log why.

```json
{
  "ok": true,
  "provider_used": "deepseek",
  "model_used": "deepseek-chat",
  "fallback": true,
  "fallback_from": ["anthropic"],
  "reason": "anthropic model unavailable"
}
```

## Explainability

Future command shape:

```sh
queue ai explain --profile balanced --capability chat,json --json
```

The explanation must include candidates considered, skips, selected provider/model, policy basis, and estimated cost/latency evidence.
