# Regulated-service live pilot runbook

This runbook is for hospital-style or similarly sensitive regulated-service environments. Rupert's enterprise assessment is pilot evidence only: queuebash is credible for dev/test and tightly governed admin workflows, but it is not cleared for broad live hospital execution.

## Live decision language

```text
Dev environment: accept for pilot.
Test deployment environment: accept for controlled implementation.
Live hospital platform: not accepted for general live execution.
Live pilot: read-only checks, backup verification, deployment preflight, and approved maintenance only.
```

## Required preflight blockers

Before any regulated live pilot, confirm:

```bash
./install-system.sh --dryrun
bin/queue-policy-wizard --scope system --dryrun --non-interactive --json
bash tests/policy_namespace_consistency_static.sh
bash tests/enterprise_default_profiles_static.sh
bash tests/ai_policy_gate_fixture_stage_smoke.sh
```

The installer and policy wizard must both report `/etc/queuebash/policies.d` as the system policy root. Do not split active policy across `/etc/bashqueues/policies.d` and `/etc/queuebash/policies.d`.

## Safe live classes

Permitted early live classes are read-only or evidence-only:

```text
status/reporting
audit-read
backup-verify
deployment-preflight-readonly
queue explain/show/list/stats/workers/events-tail
```

## Approval-required classes

Approved maintenance pilots require a named class, bounded command surface, human ticket, maintenance window, rollback command, and audit location:

```text
approved-maintenance-readwrite
approved-backup-repair
approved-index-rebuild
approved-service-restart
```

## Disabled until explicit clearance

Disable broad execution and mutation in hospital live defaults:

```text
unreviewed submit/run
remote mutation
cloud apply/destroy
secret delivery by default
break-glass by default
external AI providers by default
policy/class edits without signed approval
```

## Audit, log, and retention

The pilot owner must state:

```text
log location
audit evidence location
retention period
redaction rules
ticket system reference
approver identity requirements
```

Recommended defaults are `/var/log/queuebash`, `/var/lib/queuebash/audit`, and `/etc/queuebash/policies.d` for system policy.

## AI/provider settings

AI policy-gate use must be local-first. External providers require explicit opt-in, redaction, an approved provider profile, and evidence that no secret or regulated payload is sent off-host.

## Secrets and break-glass

Secret values must not appear in JSON, logs, scratchpads, command lines, or ordinary environment variables. Break-glass is refused by default and requires signed/dual authorisation, short TTL, ticket, reason, redacted evidence, and rollback.

## Rollback

Every approved maintenance class must document a rollback command or manual rollback procedure before execution. If rollback cannot be described, the class is not approved for live use.

## Emergency break-glass

Emergency break-glass is a separate procedure, not a normal maintenance shortcut. It must record who authorised it, why normal approval was impossible, the exact capability granted, expiry, evidence path, and post-incident review requirement.

## Staged rollout

```text
1. dev simulation
2. controlled test deployment
3. live read-only/status/reporting pilot
4. backup verification and deployment preflight pilot
5. tightly approved maintenance pilot
6. broader live execution only after explicit production clearance
```

## Enterprise profile verification command

The enterprise profile examples must be verifiable through the public queue command surface as well as the provider helper. Use:

```bash
queue enterprise list-profiles --json
queue enterprise validate-profile hospital-live-readonly-default --json
queue enterprise validate-profile hospital-live-approved-maintenance-default --json
queue enterprise validate-profile small-team-dev-default --json
queue enterprise validate-profile government-project-test-default --json
```

These commands emit fixture/contract evidence only. They do not install policy, grant live clearance, deliver secrets, or modify system state.



Enterprise validation command note:

`queue enterprise list-profiles --json`, `queue enterprise validate-profile PROFILE --json`, and `queue enterprise verify-maintenance --request FILE --json` are validation/evidence commands only. Bundled `policies.d/enterprise/*.env.example` files remain inert until deliberately copied, edited, validated, and installed through an explicit site-controlled activation process. These commands do not activate policy, grant live clearance, deliver secrets, or modify system state.
