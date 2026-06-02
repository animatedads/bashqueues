# queue AI job usage contract

This document defines how queue jobs declare AI usage without depending on a specific vendor model.

## Job declaration

Planned submit syntax:

```sh
queue submit summarise-case \
  --uses-ai \
  --ai-profile balanced \
  --ai-capability chat,json \
  --ai-max-cost 0.25 \
  -- bash ./summarise_case.sh
```

The first contract package does not implement these flags. It defines the metadata and policy model for a future runtime patch.

## Class declaration

Example class file:

```sh
CLASS_USES_AI=1
CLASS_AI_PROFILE="balanced"
CLASS_AI_ALLOWED_CAPABILITIES="chat summarize classify json"
CLASS_AI_CONTEXT_ALLOWED="docs job_metadata selected_logs"
CLASS_AI_MAX_COST_GBP="0.25"
CLASS_AI_FALLBACK_POLICY="auto"
CLASS_AI_REQUIRE_AUDIT=1
```

## Job environment

When runtime support is later added, AI-enabled jobs may receive stable variables:

```sh
QUEUEBASH_JOB_USES_AI=1
QUEUEBASH_AI_PROFILE=balanced
QUEUEBASH_AI_BROKER=1
QUEUEBASH_AI_CALL="queue ai chat"
```

The job script should call the broker:

```sh
queue ai json \
  --profile json_strict \
  --schema summary.schema.json \
  --input-file evidence.txt \
  --output-file summary.json
```

It should not hard-code `anthropic`, `openai`, `gemini`, `deepseek`, or any other vendor unless it explicitly pins a provider/model and accepts the audit implications.

## Provider pinning

Pinned provider/model usage is allowed only when explicit:

```sh
queue ai chat --provider anthropic --model claude-x --no-fallback
```

Pinned use must emit an audit event:

```json
{
  "event": "queuebash.ai.provider_pinned.v1",
  "job_id": "...",
  "provider": "anthropic",
  "model": "claude-x",
  "fallback": false
}
```

## Policy questions

The broker must answer these before any future live call:

```text
Can this class use AI?
Can this user use AI?
Can this job send data to cloud AI?
Can this job use local-only AI?
Which context bundles may be sent?
What redactions are required?
What is the budget?
Which providers are allowed?
Can it fallback across providers?
Can it use experimental models?
Can it stream?
Can it store responses?
```

Default policy should be deny for cloud/data egress until explicitly allowed.

## Fail-closed behaviour

The job must fail or wait cleanly when:

```text
no provider satisfies hard capability requirements
budget is exceeded
cloud AI is prohibited and no local provider is healthy
JSON is required but no JSON-capable model is allowed
provider health cache marks all candidates unavailable
redaction/context policy fails
```

Silent downgrade is not acceptable unless a profile explicitly allows degradation.
