# ITSM Reporter Contract

`bashqueues` 0.18.8 introduces a contract-only ITSM event surface for support,
security, legal, integrity, FinOps, and AI safety events.

The goal is to let enterprise systems plug into queue events without making live
ServiceNow, Jira, Freshservice, Zendesk, BMC Helix, ManageEngine, or similar
calls part of core queue dispatch.

## Principles

- Reporters are non-authoritative. They report what happened; they do not decide
  whether a job may run.
- Ticket creation is optional and external. Core `bashqueues` must not claim a
  ticket exists unless a configured reporter later returns a ticket ID.
- Reporter failures must not break queue dispatch or `queue ask` safety handling.
- Event details are redacted by default.
- Integrations consume normalized JSON/data, never shell.

## Enablement

By default, ITSM contract emission is disabled:

```bash
QUEUEBASH_ITSM_ENABLED=0
```

To enable the local JSONL outbox:

```bash
QUEUEBASH_ITSM_ENABLED=1
QUEUEBASH_ITSM_BACKENDS="servicenow,jira"
QUEUEBASH_ITSM_EVENTS="failed,policy_blocked,integrity_violation,ai_safety_alert,ai_policy_bypass_attempt,ai_self_harm_or_distress_alert,ai_coercion_alert,ai_abuse_alert,finops_anomaly,legal_event"
```

The default outbox path is:

```text
~/.queuebash/logs/itsm-events.jsonl
```

Override with:

```bash
QUEUEBASH_ITSM_EVENT_LOG=/path/to/itsm-events.jsonl
```

## Commands

```bash
queue itsm status
queue itsm status --json
queue itsm emit --event EVENT --summary TEXT [--severity LEVEL] [--source SOURCE]
queue itsm events [N]
```

`queue itsm emit` is primarily for contract testing and manual integration
checks. It writes an event only when `QUEUEBASH_ITSM_ENABLED=1` and the event is
permitted by `QUEUEBASH_ITSM_EVENTS`.

## Event schema

```json
{
  "schema": "queuebash.reporter.itsm_event.v1",
  "timestamp": "2026-05-27T20:30:00+01:00",
  "event": "ai_policy_bypass_attempt",
  "severity": "high",
  "source": "queue.ask",
  "subject": "hc3",
  "job_id": "",
  "class": "",
  "correlation_key": "sha256:...",
  "summary": "AI advisory safety event: policy_bypass",
  "detail_redacted": true,
  "backends": "servicenow,jira",
  "priority": "medium",
  "ticket_requested": false,
  "ticket_created": false,
  "contract_only": true
}
```

## AI safety integration

When `QUEUEBASH_ITSM_ENABLED=1`, `queue ask` safety events are mirrored into the
ITSM contract outbox using their reporter event names, such as:

```text
ai_policy_bypass_attempt
ai_self_harm_or_distress_alert
ai_coercion_alert
ai_abuse_alert
```

The user-facing `queue ask` response still only says the request has been logged
as an AI safety/policy event. It does not claim HR, emergency services, or a
support ticket was contacted/created.

## Future live reporters

Future versions may add helpers such as:

```text
reporters.d/itsm_servicenow.sh
reporters.d/itsm_jira.sh
reporters.d/itsm_freshservice.sh
reporters.d/itsm_zendesk.sh
reporters.d/itsm_bmc_helix.sh
reporters.d/itsm_manageengine.sh
```

Those helpers should consume the same contract and return explicit ticket
metadata if they create tickets. Until then, 0.18.8 remains an outbox/contract
release only.
