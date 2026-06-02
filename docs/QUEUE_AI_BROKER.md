# queue AI broker contract

`queue ai broker` is the proposed provider-neutral capability layer for jobs that need AI service during execution.

The governing rule is:

```text
Jobs ask for AI capability, profile, budget, and policy constraints.
Jobs do not hard-code a vendor model unless they deliberately pin one.
```

This contract extends the existing `queue ask` provider-neutral advisory work from human/operator questions into job-execution use cases. The first delivery is intentionally contract-only: it defines interfaces, policy shape, audit evidence, and fixture tests, but does not add a runtime broker or any live provider call.

## Goals

The broker resolves:

```text
required capability
AI profile
available providers
available models
provider/model health
policy permission
cost constraints
privacy/locality constraints
fallback order
context limits
JSON/tool/streaming support
```

Then it either performs a governed AI call on behalf of the job, or returns a short-lived brokered lease that lets a compatible tool use an assigned endpoint.

## Non-goals for this contract package

```text
no runtime broker implementation
no live provider API calls
no credentials required
no endpoint leasing implementation
no queue dispatch refactor
no provider-specific feature sprawl
no automatic job submission/execution based on model output
```

## Operating modes

### Brokered call

The job calls bashqueues, and bashqueues handles provider selection, redaction, request normalization, fallback, audit, and response normalization.

Planned command shape:

```sh
queue ai chat --profile balanced --message "Summarise this"
queue ai json --profile json_strict --schema result.schema.json --input-file input.txt
```

### Brokered lease

The job asks bashqueues for a short-lived provider/model assignment.

Planned command shape:

```sh
queue ai lease --capability chat --profile balanced --json
```

Example lease response:

```json
{
  "schema": "queuebash.ai.lease.v1",
  "ok": true,
  "lease_id": "ai_20260602_abc123",
  "provider": "openai_compat",
  "model": "local-model",
  "endpoint_env": "QUEUEBASH_AI_ENDPOINT_FILE",
  "expires_at": "2026-06-02T12:30:00Z"
}
```

Brokered call is the safer first runtime stage. Brokered lease is for third-party tools that already expect an OpenAI-compatible endpoint.

## AI profiles

A profile describes what the job needs. It is not a literal vendor model.

Example profiles:

```text
cheap
balanced
high_quality
local_only
private_only
fast
long_context
json_strict
code
vision
speech
offline
```

Profile files live under:

```text
/etc/bashqueues/policies.d/ai-profiles/
```

Example:

```sh
AI_PROFILE_NAME="balanced"
AI_CAPABILITIES="chat summarize classify json"
AI_PROVIDER_ORDER="openai_compat deepseek gemini anthropic mistral ollama"
AI_COST_STRATEGY="prefer_low_cost"
AI_MAX_COST_PER_REQUEST_GBP="0.05"
AI_MAX_LATENCY_SECONDS="60"
AI_ALLOW_CLOUD=1
AI_ALLOW_LOCAL=1
AI_REQUIRE_AUDIT=1
AI_FALLBACK_ENABLED=1
AI_HEALTH_REQUIRED=1
```

## Provider/model registry

The broker consumes a provider registry that describes capabilities and cost/health hints. It must not blindly trust static registry data; runtime health updates can disable or cool down a provider/model.

Required normalized fields:

```text
provider
model
capabilities
context_tokens
supports_json
supports_schema_json
supports_tools
supports_streaming
location_type local|cloud|private
cost_input_per_million
cost_output_per_million
health_state
priority
```

Health states:

```text
available
degraded
rate_limited
auth_failed
model_missing
timeout
disabled_by_policy
disabled_by_cost
cooldown
```

## Selection order

The broker selection rule is fail-closed and auditable:

```text
1. provider allowed by policy
2. model supports requested capability
3. privacy/locality rule satisfied
4. runtime health acceptable
5. estimated cost within budget
6. latency/quality preference satisfied
7. highest policy score wins
```

If no provider satisfies the hard requirements, the broker must deny the request rather than silently degrading.

## Normalized request envelope

```json
{
  "schema": "queuebash.ai.broker.request.v1",
  "operation": "chat",
  "profile": "balanced",
  "capabilities": ["chat", "json"],
  "messages": [
    {"role": "system", "content": "You are assisting a queue job."},
    {"role": "user", "content": "Summarise this file."}
  ],
  "constraints": {
    "max_cost_gbp": 0.05,
    "max_latency_seconds": 60,
    "allow_cloud": true,
    "allow_local": true,
    "require_json": true
  },
  "context": {
    "job_id": "20260602_...",
    "class": "AI_SUMMARY",
    "allowed_contexts": ["docs", "job_metadata"]
  }
}
```

## Normalized response envelope

```json
{
  "schema": "queuebash.ai.broker.response.v1",
  "ok": true,
  "text": "...",
  "json": {},
  "provider": "gemini",
  "model": "gemini-...",
  "usage": {
    "input_tokens": 1234,
    "output_tokens": 456,
    "estimated_cost_gbp": 0.002
  },
  "fallback": {
    "used": true,
    "attempted": ["anthropic"],
    "reason": "model unavailable"
  }
}
```

## Audit events

Every broker call emits safe JSONL audit metadata. Full prompts, credentials, and unredacted files are not logged by default.

```json
{
  "event": "queuebash.ai.request.v1",
  "job_id": "...",
  "class": "AI_SUMMARY",
  "profile": "balanced",
  "capabilities": ["chat", "json"],
  "selected_provider": "gemini",
  "selected_model": "gemini-...",
  "fallback_used": true,
  "fallback_from": ["anthropic"],
  "cost_estimate_gbp": 0.003,
  "context_bundle_ids": ["docs:abc123", "job_metadata:def456"],
  "redactions": ["secrets", "env"],
  "policy_decision": "allowed"
}
```

Provider failures are separate events:

```json
{
  "event": "queuebash.ai.provider_failure.v1",
  "provider": "anthropic",
  "model": "claude-x",
  "reason": "model unavailable",
  "cooldown_seconds": 3600
}
```

## Relationship to `queue ask`

`queue ask` remains the human/operator advisory interface. `queue ai broker` is the job-facing capability broker. They may share provider adapters, redaction helpers, audit schemas, and context-bundle logic, but the command surfaces remain distinct.

## Future runtime staging

```text
1. contract/docs/policy/tests only
2. queue ai providers/models/health/explain inventory
3. queue ai chat/json brokered calls using existing ask-provider helpers
4. queue submit --uses-ai metadata and class policy gates
5. cost/fallback scoring and health cache
6. brokered lease for OpenAI-compatible clients
```
