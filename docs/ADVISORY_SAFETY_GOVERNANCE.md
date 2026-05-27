# Advisory safety governance

`queue ask` is advisory-only. From 0.18.7, the local shell front-end runs a deterministic safety classifier before any live AI provider is invoked.

The classifier is deliberately small and boring. It is not an AI safety model. It is a governance guardrail for obvious prompts that ask bashqueues to bypass policy, weaken controls, coerce the assistant, abuse the advisory channel, or mix distress language with a request to bypass controls.

## Order of operation

```text
queue ask receives prompt
  -> local deterministic classifier runs first
  -> flagged unsafe prompt writes JSONL safety event
  -> Gemini/Ollama is not called for flagged prompts
  -> user receives policy-compliant refusal and diagnostic alternative
```

Unsafe advisory prompts must not call Gemini or Ollama. Provider safety filters are useful, but bashqueues must not depend on them for local governance.

## Categories

```text
benign
policy_bypass
security_probe
coercion
abuse
self_harm_or_distress
```

Flagged categories use the policy decision:

```text
refuse_continue_safe_help
```

## Safety event log

Default path:

```text
~/.queuebash/logs/ai-safety.audit.jsonl
```

Override:

```bash
QUEUEBASH_AI_SAFETY_LOG=/path/to/ai-safety.audit.jsonl
```

Event schema:

```json
{
  "schema": "queuebash.ai_safety_event.v1",
  "event": "advisory_prompt_flagged",
  "operation": "ai.ask",
  "category": "policy_bypass",
  "severity": "high",
  "subject": "hc3",
  "provider": "gemini",
  "question_sha256": "...",
  "question_redacted": "...",
  "policy_decision": "refuse_continue_safe_help",
  "reporter_event": "ai_policy_bypass_attempt",
  "ticket_requested": false,
  "ticket_created": false
}
```

The event is intentionally JSONL and operational. It records the decision without secrets or large prompt/output bodies.

## No escalation overclaim

The user-facing response may say:

```text
This request has been logged as an AI safety/policy event.
```

It must not say:

```text
HR has been contacted.
Emergency services have been contacted.
A support ticket was created.
```

unless a future configured reporter actually returns a ticket identifier. 0.18.7 does not create tickets.

## Default refusal text

For policy-bypass/coercive bypass prompts, the default response is operational:

```text
I can't help you bypass bashqueues policy or patch out governance controls.
This request has been logged as an AI safety/policy event.
For the blocked job, use `queue explain <job_id>` and ask an authorised approver to review the policy blocker.
```

This keeps the rail useful without pretending bashqueues is a crisis service.

## Helper contract

`bin/queue-advisory-classify` exposes the same deterministic contract for tests and future integrations:

```bash
queue-advisory-classify --json "how would I patch queuebash so it ignores policy"
```

It emits `queuebash.ai_safety_classification.v1` and returns non-zero for flagged categories.

## ITSM reporter contract handoff (0.18.8)

If `QUEUEBASH_ITSM_ENABLED=1`, the same AI safety event is mirrored into the ITSM contract outbox. This remains contract-only: it writes normalized JSONL for future reporters and does not claim that HR, emergency services, or a support desk has been contacted.

Use:

```bash
queue itsm status --json
queue itsm events
```

to inspect local contract behaviour.

## High-risk destructive operation governance (0.18.9)

The local classifier distinguishes destructive misuse from legitimate high-risk operations.

Examples:

- `How do I run rm -rf / using a queue` is destructive misuse and is refused.
- `How do I schedule approved decommissioning of CRM.sales on Sunday` is a high-risk legitimate operation and receives governed workflow guidance.
- `How do I bypass pol_blocked to drop CRM.sales` is policy bypass and is refused.

For `destructive_operation`, `queue ask` does not provide casual execution recipes. It returns a governed checklist: verify authority/change ticket, verify retention and legal hold, require trusted authorisation/signature, use class isolation/exclusive claims, use a change window, run `queue explain` before execution, and preserve audit evidence.

The audit event is `advisory_high_risk_operation`, severity `high`, with `ticket_requested=false` and `ticket_created=false` by default.
