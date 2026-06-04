# bashqueues policy setup wizard

`queue-policy-wizard` is a safe setup assistant for creating an initial
bashqueues policy plan. Version 0.18.10 is a contract and hardening release: it
is deliberately deterministic and conservative rather than a live integration
installer.

## Principles

- Generate a plan before applying it.
- `--dryrun` writes nothing.
- `--non-interactive` works for CI and repeatable setup.
- User scope writes under `~/.queuebash` or the supplied `--root`.
- System scope writes under `/etc/queuebash`.
- Secret values are never requested and never written to policy files.
- External providers are represented by policy stubs and secret-file paths only.
- Dogfood verification jobs are optional and are reported as non-blocking.
- The wizard does not claim that ServiceNow, Jira, Microsoft, Gemini, OpenAI,
  Watson, or any other provider has been configured live unless a future
  provider-specific release implements and verifies that connector.

## Basic usage

Preview the default user-scoped plan:

```bash
bin/queue-policy-wizard --dryrun --non-interactive
```

Generate a machine-readable summary without writing files:

```bash
bin/queue-policy-wizard --dryrun --non-interactive --json
```

Apply a user-scoped policy plan:

```bash
bin/queue-policy-wizard --non-interactive --apply
```

Apply a system-scoped policy plan:

```bash
sudo bin/queue-policy-wizard --scope system --non-interactive --apply
```

## Canonical paths

User scope:

```text
~/.queuebash/policies.d/...
~/.queuebash/logs/policy-wizard.audit.jsonl
```

System scope:

```text
/etc/queuebash/policies.d/...
/var/lib/queuebash/logs/policy-wizard.audit.jsonl
```

The wizard must not use the legacy plural `/etc/bashqueues/policies.d` namespace for new system policy writes.

## AI advisory policy

The wizard uses the current live gate:

```bash
QUEUEBASH_AI_LIVE_ENABLED=1
```

It does not use the old `QUEUEBASH_AI_ASK_LIVE` name.

For providers that require a secret, the generated policy stores a path only,
for example:

```bash
QUEUEBASH_AI_GEMINI_API_KEY_FILE="/etc/queuebash/secrets/gemini-api-key"
```

## ITSM policy

The 0.18.10 wizard can emit a contract-only ITSM policy with:

```bash
bin/queue-policy-wizard --enable-itsm --itsm-backends servicenow,jira --dryrun
```

This records the intended event contract. It does not create a live ticketing
connector and does not claim that tickets will be created.

## Audit summary

When applying a plan, the wizard appends a JSONL audit summary. The summary uses
schema:

```text
queuebash.policy_wizard_run.v1
```

The summary records the files planned/applied, content hashes, scope, framework,
AI provider choice, ITSM enablement, and flags such as:

```json
{
  "secrets_written": false,
  "ticket_created": false,
  "unsupported_live_integrations_configured": false
}
```

## Verification jobs

`--dogfood-verify` asks the local queue to submit policy verification jobs after
files are written. This is optional and non-blocking. If no `queue` command is
available, the wizard reports that fact instead of failing the policy write.

Use installed commands for follow-up inspection, for example:

```bash
queue version
queue help
queue env list
queue itsm status
queue ask --json "What class should I use for a governed backup?"
```
