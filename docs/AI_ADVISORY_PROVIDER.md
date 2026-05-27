# AI advisory provider contract

`queue ask` is an advisory only interface for helping users and administrators understand how to use bashqueues to achieve an operational or business outcome.

It is deliberately not a control-plane authority. It cannot approve, submit, cancel, sign, override, patch, or execute jobs by itself.

## Command

```bash
queue ask [--provider NAME] [--context csv] [--json] "question"
```

Examples:

```bash
queue ask "How do I run this workload overnight without breaching GDPR policy?"
queue ask --provider watson --context docs,commands,classes "Which class should I use for a legal readonly job?"
queue ask --context docs,commands,classes,queue_status --json "Why are my jobs not draining?"
```

In this contract release, `queue ask` builds a deterministic, policy-gated provider handoff and audit record. Live AI provider calls are intentionally not implemented here.

## Design rule

AI may explain bashqueues. AI does not become bashqueues.

Provider output is data. It is never evaluated as shell and never receives authority to bypass policy.

## Provider-neutral responders

An AI advisory provider may be implemented by:

- IBM Watson or watsonx
- OpenAI
- Azure OpenAI
- Gemini
- an internal enterprise LLM
- a local/offline RAG responder
- a manual-only deterministic responder

The provider implementation is selected by configuration or `--provider NAME`. The contract is open and provider-neutral.

## Context categories

Context is disclosed only when policy allows it.

Always-safe default categories:

- `docs`
- `manuals`
- `commands`
- `classes`
- `assets`
- `providers`

Restricted categories:

- `queue_status`
- `job_status`
- `job_metadata`
- `policy_details`
- `profile_details`

The default command implementation allows docs/commands/classes/providers and denies queue/job/policy/profile detail unless explicitly enabled by policy or environment, for example:

```bash
QUEUEBASH_AI_ALLOW_QUEUE_STATUS=1
QUEUEBASH_AI_ALLOW_POLICY_DETAILS=1
```

Future enterprise implementations should resolve these decisions through the same operation-ACL/provider model used for Microsoft, LDAP, PAM.d/NSS, and file-backed providers.

## Request JSON contract

```json
{
  "schema": "queuebash.ai_advisory.request.v1",
  "timestamp": "2026-05-27T14:30:00Z",
  "operation": "ai.ask",
  "subject": "alice",
  "provider": "watson",
  "question_sha256": "...",
  "question_redacted": "How do I run a GDPR-safe overnight job?",
  "context_requested": "docs commands classes queue_status",
  "context_allowed": "docs commands classes",
  "context_denied": "queue_status",
  "context_bundle_sha256": "...",
  "advisory_only": true,
  "provider_execution": "not_implemented_contract_only"
}
```

A live provider helper must consume a normalized request bundle, not raw shell fragments. It must return a normalized advisory response.

## Future helper contract

A future helper may be invoked as:

```bash
queue-ai-ask --provider watson --request-json /path/request.json --context-bundle /path/context.json
```

Expected response shape:

```json
{
  "schema": "queuebash.ai_advisory.response.v1",
  "provider": "watson",
  "decision": "answered",
  "answer_markdown": "...",
  "citations": [
    {"type": "manual", "id": "docs/TRUST_PROVIDERS.md"}
  ],
  "actions_suggested": [
    {"command": "queue env list", "authority": "suggestion_only"}
  ],
  "redactions_observed": true,
  "response_sha256": "..."
}
```

`actions_suggested` are never executed by `queue ask`.

## Operation ACL

`queue ask` corresponds to operation:

```text
ai.ask
```

Enterprise installations may define separate ACLs for context disclosure:

```text
ai.context.docs
ai.context.commands
ai.context.classes
ai.context.queue_status
ai.context.job_metadata
ai.context.policy_details
ai.context.profile_details
```

Single-user installations need not know about this enterprise backplate; the file-backed/default model remains simple.
