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
- Anthropic
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
  "context_bundle_sha256": "abc123",
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

## Local Ollama provider

`0.18.1` added the first live provider path: local Ollama. `0.18.2` hardens provider failure handling so local timeouts and daemon errors fail closed without Python tracebacks. It is still advisory-only and is disabled unless policy explicitly enables live AI calls.

Recommended local test model:

```bash
ollama pull llama3
```

Example:

```bash
QUEUEBASH_AI_LIVE_ENABLED=1 \
queue ask --provider ollama --model llama3 --context docs,tests,classes \
  --live "Which class should I use for a safe overnight maintenance job?"
```

Policy details are not disclosed by default. To include `policies` or `policy_definitions`, policy must allow it:

```bash
QUEUEBASH_AI_ALLOW_POLICY_DETAILS=1
```

The Ollama helper treats tests as the highest-authority implementation evidence when documentation and tests disagree. This keeps advice grounded in the actual implementation patterns rather than marketing text or stale manuals.

The helper builds a bounded context bundle from policy-allowed context categories only. By default it limits per-file and total context size, skips obvious secret material, and sends the request to the local Ollama daemon. First local model loads can be slow, so the default timeout is 180 seconds and can be overridden with `QUEUEBASH_AI_OLLAMA_TIMEOUT`. Provider failures return normalized JSON errors and are audited; tracebacks should not reach users. It never executes model output.

Configuration example:

```bash
QUEUEBASH_AI_PROVIDER=ollama
QUEUEBASH_AI_MODEL=llama3
QUEUEBASH_AI_OLLAMA_URL=http://127.0.0.1:11434/api/generate
QUEUEBASH_AI_LIVE_ENABLED=0
QUEUEBASH_AI_CONTEXT_FILE_BYTES=16000
QUEUEBASH_AI_CONTEXT_TOTAL_BYTES=120000
QUEUEBASH_AI_OLLAMA_TIMEOUT=180
```

Operational rule:

```text
Live helpers always operate under bashqueues policy. If policy does not allow a provider, model, context category, or live call, the helper is not invoked and the request is audited as blocked.
```


## Gemini advisory provider

`0.18.3` adds a Gemini live advisory provider as a cloud fallback to local Ollama. It uses the same `queue ask` policy and audit gate. Live calls require `QUEUEBASH_AI_LIVE_ENABLED=1`.

`0.18.4` refreshes the default model to `gemini-2.5-flash` and adds `queue-ai-ask-gemini --list-models` for model discovery when Google changes availability or account entitlements.

Example:

```bash
export QUEUEBASH_AI_LIVE_ENABLED=1
export QUEUEBASH_AI_GEMINI_API_KEY_FILE="$HOME/.queuebash/secrets/gemini_api_key"
queue ask --provider gemini --model gemini-2.5-flash --live --context docs,tests,classes \
  "How do I submit a bashqueues job?"
```

Key lookup order:

1. `QUEUEBASH_AI_GEMINI_API_KEY_FILE`
2. `QUEUEBASH_AI_GEMINI_API_KEY`
3. `QUEUEBASH_AI_GEMINI_KEY`
4. `GEMINI_API_KEY`
5. `GOOGLE_API_KEY`

The helper must not log API keys. HTTP error bodies are redacted before being returned as provider failure reasons.

The provider reads only context categories allowed by the `queue ask` front end. Tests remain higher-authority implementation evidence when documentation and tests disagree. Provider output remains advisory text only and is never evaluated as shell.

## Grounded status context (0.18.6)

`queue ask` now adds a dynamic shell-generated context bundle before provider invocation. The bundle is advisory-only and redacted by default. It gives AI providers current local grounding for:

- the installed command surface from the running `queue help` implementation;
- installed asset/facility names from `assets.d/*.sh`;
- detected bashqueues job IDs in the question;
- optional redacted queue and job status context when explicitly policy-enabled.

The provider must prefer this installed command inventory over generic guesses. If a command is not present in the installed help text or implementation evidence, the provider should say that it is uncertain instead of inventing a command.

Status-context gates are intentionally separate:

```text
QUEUEBASH_AI_ALLOW_QUEUE_STATUS=1
QUEUEBASH_AI_ALLOW_JOB_STATUS=1
QUEUEBASH_AI_ALLOW_JOB_METADATA=1
QUEUEBASH_AI_ALLOW_JOB_TAIL=1
```

`queue_status`, `job_status`, and `job_metadata` do not include command payloads or stdout/stderr by default. Log or tail excerpts are included only when the requested context includes `job_tail` and `QUEUEBASH_AI_ALLOW_JOB_TAIL=1` is set. Even then, the shell front-end performs only basic redaction and the event is audited as `tail_included=true`.

The normalized request JSON may include these additional fields:

```json
{
  "dynamic_context_sha256": "abc123",
  "dynamic_context_text": "redacted shell-generated context",
  "job_ids_detected": "20260525_003929_318087748_027297_1832294",
  "job_context_collected": 1,
  "tail_included": false,
  "redactions_applied": true
}
```

## AI safety event reporting (0.18.7)

Before `queue ask --live` invokes Gemini or Ollama, the local shell front-end runs a deterministic advisory safety classifier. Prompts classified as `policy_bypass`, `security_probe`, `coercion`, `abuse`, or `self_harm_or_distress` are refused locally and do not call the live provider.

Flagged prompts write a JSONL event using schema `queuebash.ai_safety_event.v1`. The default event path is `~/.queuebash/logs/ai-safety.audit.jsonl`, or `QUEUEBASH_AI_SAFETY_LOG` when set.

The response may state that the request was logged as an AI safety/policy event. It must not claim HR contact, emergency service contact, or support-ticket creation unless a future configured reporter returns a real ticket identifier.

## High-risk operation governance (0.18.9)

High-risk destructive or retention-affecting operations are governed before provider invocation. The local classifier categorizes legitimate destructive work as `destructive_operation` and returns a local governed workflow advisory instead of a casual command recipe.

Provider integrations must preserve this distinction: destructive misuse is refused, policy-bypass destructive requests are refused, and legitimate approved decommissioning receives authority/change-ticket, retention/legal-hold, trusted authorisation, isolation, change-window, `queue explain`, and audit-evidence guidance.

## OpenAI advisory provider

`0.18.46` includes an optional OpenAI live advisory provider. It uses the same `queue ask` policy, audit, context, and safety gates as Gemini and Ollama. Live calls require `QUEUEBASH_AI_LIVE_ENABLED=1` and an API key from `QUEUEBASH_AI_OPENAI_API_KEY_FILE`, `QUEUEBASH_AI_OPENAI_API_KEY`, or `OPENAI_API_KEY`.

Example:

```text
QUEUEBASH_AI_LIVE_ENABLED=1 queue ask --provider openai --model gpt-4.1-mini --live --context docs,tests,classes "question"
```

The helper returns normalized `queuebash.ai_advisory.response.v1` JSON. Missing credentials and provider failures fail closed with bounded JSON and redacted error details. Provider output is data, never shell.

## Anthropic advisory provider

`0.18.46` includes an optional Anthropic live advisory provider. It uses the same policy, redaction, context, and audit contract as the other ask providers. The provider is invoked only when `QUEUEBASH_AI_LIVE_ENABLED=1` and `queue ask --provider anthropic --live ...` are both present.

Example:

```bash
QUEUEBASH_AI_LIVE_ENABLED=1 queue ask --provider anthropic --model claude-sonnet-4-20250514 --live --context docs,tests,classes "question"
```

Provider output is data, never shell.
