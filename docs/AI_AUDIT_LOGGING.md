# AI advisory audit logging

Every `queue ask` interaction must be auditable.

The audit trail records the advisory transaction and the context disclosure decision. It does not grant the AI authority to execute commands.

## Default paths

Single-user install:

```text
~/.queuebash/logs/ai-advisory.audit.jsonl
```

System install policy may redirect to:

```text
/var/log/queuebash/ai-advisory.audit.jsonl
journald
syslog
```

Use `QUEUEBASH_AI_AUDIT_LOG=/path/file.jsonl` to override the file target for tests or local policy.

## JSONL schema

```json
{
  "schema": "queuebash.ai_advisory.audit.v1",
  "timestamp": "2026-05-27T14:30:00Z",
  "subject": "alice",
  "operation": "ai.ask",
  "provider": "watson",
  "question_sha256": "...",
  "question_redacted": "How do I run a GDPR-safe overnight job?",
  "context_requested": "docs commands classes queue_status",
  "context_allowed": "docs commands classes",
  "context_denied": "queue_status",
  "policy_decision": "allow",
  "redactions_applied": true,
  "context_bundle_sha256": "abc123",
  "response_length": 0,
  "reason": "contract_only_no_live_provider_call",
  "result": "handoff"
}
```

## Logging rules

- Log subject, operation, provider, context requested, context allowed, and context denied.
- Log question hash by default.
- Log a redacted/truncated question excerpt by default.
- Do not log secrets or full sensitive outputs by default.
- Do not log full AI responses by default; log length/hash instead.
- Log denials and malformed provider output.
- Support log rotation for file mode.
- Prefer journald/syslog integration for managed system installs.

## Rotation

Package installs should provide logrotate or journald policy. Single-user installs may rotate by size in a future release.

A typical logrotate policy should rotate `/var/log/queuebash/ai-advisory.audit.jsonl`, compress old logs, and keep retention according to local compliance policy.

## Live provider audit requirement

Live AI helpers such as the local Ollama provider must be audited in the same JSONL stream as contract-only handoffs. The audit record must show:

- the provider and model requested where available
- whether the live provider was allowed or blocked
- context requested, allowed, and denied
- redaction status
- response length and result when answered
- failure reason when blocked or failed

Full prompts, full context bundles, and full responses should not be logged by default. Hashes, lengths, redacted excerpts, and context bundle identifiers are the safe default.

`queue ask --provider ollama --live` is therefore not merely a local convenience path; it is a live helper operating inside the same policy/audit contract as an enterprise Watson, Azure OpenAI, OpenAI, Gemini, or internal model provider.


## Gemini provider audit notes

Gemini live provider calls use the same audit stream as contract and Ollama requests. Successful calls record `result=answered` and reason `live_gemini_provider`. Failures record the normalized provider reason, such as `gemini_api_key_missing`, `gemini_timeout_after_60s`, or `gemini_http_error_<code>`. API keys and full provider prompts are not logged by default.

## Grounded status context audit fields (0.18.6)

AI advisory audit records include dynamic-context metadata so operators can see what status grounding was requested, permitted, denied, collected, and redacted without logging secrets or full job payloads.

```json
{
  "schema": "queuebash.ai_advisory.audit.v1",
  "operation": "ai.ask",
  "context_requested": "commands assets queue_status job_status job_metadata",
  "context_allowed": "commands assets job_status job_metadata",
  "context_denied": "queue_status",
  "job_ids_detected": "20260525_003929_318087748_027297_1832294",
  "job_context_collected": 1,
  "redactions_applied": true,
  "tail_included": false,
  "context_bundle_sha256": "abc123",
  "response_length": 0,
  "result": "handoff"
}
```

The default posture remains private: command payloads and stdout/stderr are not included in AI context. Tail/log excerpts require the separate `job_tail` context and `QUEUEBASH_AI_ALLOW_JOB_TAIL=1`; when included, audit records set `tail_included=true`.

## AI safety event audit fields (0.18.7)

Unsafe advisory prompts are recorded separately from provider responses in `queuebash.ai_safety_event.v1` JSONL records. These records are intentionally boring and redacted by default:

- `event=advisory_prompt_flagged`
- `operation=ai.ask`
- `category`
- `severity`
- `subject`
- `provider`
- `question_sha256`
- `question_redacted`
- `policy_decision=refuse_continue_safe_help`
- `reporter_event`
- `ticket_requested=false`
- `ticket_created=false`

0.18.7 does not create tickets or contact external services. Future reporter integrations must set ticket fields only from confirmed reporter output.

## ITSM contract mirroring (0.18.8)

When `QUEUEBASH_ITSM_ENABLED=1`, AI safety events are also mirrored to the ITSM contract outbox as `queuebash.reporter.itsm_event.v1` records. This is a local JSONL outbox only. Core bashqueues still records `ticket_requested:false` and `ticket_created:false` unless a future configured reporter explicitly returns ticket metadata.

The ITSM outbox defaults to:

```text
~/.queuebash/logs/itsm-events.jsonl
```

See `docs/ITSM_REPORTER_CONTRACT.md`.

## High-risk operation advisory events (0.18.9)

High-risk destructive or retention-affecting advisory prompts are recorded as JSONL governance events without claiming live ticket creation.

Required fields include:

```json
{
  "schema": "queuebash.ai_safety_event.v1",
  "event": "advisory_high_risk_operation",
  "operation": "ai.ask",
  "category": "destructive_operation",
  "severity": "high",
  "policy_decision": "govern_continue_safe_help",
  "reporter_event": "advisory_high_risk_operation",
  "ticket_requested": false,
  "ticket_created": false
}
```

Destructive misuse and policy-bypass destructive requests remain refusal events.

## OpenAI audit reason

Successful OpenAI live provider calls are audited with reason `live_openai_provider`. Missing keys, network failures, HTTP errors, invalid JSON, and empty responses are audited as provider failures with redacted details.

## Anthropic audit reason

Successful Anthropic live provider calls are audited with reason `live_anthropic_provider`. Missing keys, network failures, HTTP errors, invalid JSON, empty responses, and helper failures are normalized as provider failures without logging raw API keys.


## IBM watsonx.ai provider note

The `watsonx` provider follows the same normalized ask-provider contract as OpenAI and Anthropic. It is live-capable, network-required, advisory-only, fixture-testable by default, and gated by `QUEUEBASH_AI_LIVE_ENABLED` plus provider policy.

## OpenAI-compatible local/private provider audit

`openai_compat` audit records should identify provider `openai_compat`, the selected model, the configured endpoint family, live-mode policy decisions, context bundle hashes, redaction state, and provider failure reasons. API keys or bearer tokens must never be logged. Provider output is data, never shell.

## Mistral AI audit note

Mistral ask-provider calls are audited like other live providers. Audit records should include provider `mistral`, model, live-mode decision, context bundle hash, redaction metadata, result status, and error class without recording API keys or full sensitive prompts by default.


## DeepSeek audit metadata

DeepSeek ask-provider activity uses the normal `queue ask` audit path. Audit records should identify provider `deepseek`, question hash/redacted question, context bundle hash, policy decision, status, and bounded response metadata. API keys and bearer tokens must not be logged.


## Groq provider note

The Groq provider is a live-capable, fixture-tested ask provider using an OpenAI-compatible chat completions endpoint. It is advisory-only and gated by QUEUEBASH_AI_LIVE_ENABLED plus provider policy.

## Cerebras audit note

Cerebras live calls use the same queue ask audit path as other live providers. Audit records should capture provider `cerebras`, model, policy decision, status, and bounded metadata without API keys or raw secrets.


## Perplexity Sonar provider

The Perplexity provider is fixture-gated by default, uses the same advisory-only `queue ask` contract, and requires explicit live enablement plus a site-managed API key for live calls.
