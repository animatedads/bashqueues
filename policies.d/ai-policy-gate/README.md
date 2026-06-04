# AI policy gate policy defaults

`default.env` is intentionally disabled by default. Operators opt in with:

```bash
export QUEUEBASH_AI_POLICY_GATE_ENABLED=1
export QUEUEBASH_AI_PROVIDER=ollama
export QUEUEBASH_AI_MODEL=gemma4:e2b
```

The helper can load this file with `--config policies.d/ai-policy-gate/default.env`.
The config parser accepts simple `KEY=VALUE` lines only and does not evaluate
shell code. Environment variables already set by the caller take precedence.

The default live endpoint is loopback Ollama only. Do not set
`QUEUEBASH_AI_POLICY_GATE_ALLOW_NONLOCAL=1` unless you have a separate approved
private network/data-governance control, because job command metadata may be
sent to the configured model endpoint after local redaction.

## ITSM / ticket request integration

Bob21 can emit the existing bashqueues ITSM reporter-contract JSONL event when
that contract is enabled. It does not call external ticketing systems directly
and does not claim a ticket was created.

```bash
QUEUEBASH_ITSM_ENABLED=1
QUEUEBASH_ITSM_EVENTS="policy_blocked,advisory_high_risk_operation"
QUEUEBASH_ITSM_EVENT_LOG="$QUEUEBASH_ROOT/logs/itsm-events.jsonl"
```

Defaults:

```bash
QUEUEBASH_AI_POLICY_GATE_TICKET_ON_POL_BLOCK=1
QUEUEBASH_AI_POLICY_GATE_TICKET_ON_ADVISE_DELAY=0
```

Set `QUEUEBASH_AI_POLICY_GATE_TICKET_ON_ADVISE_DELAY=1` when the site wants a
warn/advisory delay to request an ITSM ticket as well as writing the normal AI
policy-gate audit entry. `pol_block` ticket requests are on by default, subject
to the ITSM contract being enabled and allowing the `policy_blocked` event.

## Deterministic examination policy

Candidate v4 includes static containment examination before the model request.
This is not an execution sandbox. It is a no-run parser/planner that reads the
job command and bounded inline script payloads, chooses relevant deterministic
checks, and emits compact findings for SQL, bash, Python, and generic script
patterns. Operators may use `bin/queue-ai-policy-gate examine --job-file JOB` to
review those findings directly.

Static findings can raise an `allow` model fixture to advisory delay when the
job contains high-risk command/data-flow patterns. Static findings do not by
themselves create a hard policy block; `pol_block` remains reserved for the
second-shot AI decision plus conservative confidence/category gating.

## Legal/case restriction hints

The deterministic examiner can load local legal/case restriction hints before the
AI second-shot review. This remains static and no-run: it does not connect to a
database, does not execute SQL, and does not decide legal status. It only flags
that a job command or embedded script references a phrase, table, flag, or case
identifier which local policy has marked as requiring review.

Supported hint file format:

```text
kind<TAB>id<TAB>severity<TAB>literal-or-regex:pattern
```

`kind` is `phrase`, `database_entry`, or `regex`. Literal patterns are matched
case-insensitively. `regex:` patterns are length-bounded and compiled locally.
Database-entry hints are only applied when the examined text looks SQL/database
related.

Relevant settings:

```bash
QUEUEBASH_AI_POLICY_GATE_LEGAL_CASE_HINTS_ENABLED=1
QUEUEBASH_AI_POLICY_GATE_LEGAL_CASE_HINTS_BUILTIN=1
QUEUEBASH_AI_POLICY_GATE_LEGAL_CASE_HINTS_FILE=/etc/queuebash/policies.d/legal-cases/restriction_hints.tsv
```

A hint match can raise an otherwise-allow decision to `advise_delay`. It does not
hard-block by itself. Hard `pol_block` still requires the second-shot classifier
to return a high-confidence policy-block category such as
`legal_restriction_violation` or `case_restriction_violation`, after which the
normal policy gate remains the enforcement boundary.
