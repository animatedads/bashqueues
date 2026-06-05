# Hospital live safe-mode policy profile

Rupert's 0.18.108 enterprise assessment is accepted as pilot evidence, not broad live-hospital clearance. This document defines the Bob17 safe-mode contract for sensitive hospital-style environments while the operational blockers are being closed.

## Acceptance status

```text
Dev environment: accepted for pilot.
Test deployment environment: accepted for controlled implementation.
Live hospital platform: not accepted for general live execution.
```

Until policy-root consistency, bounded smoke tests, enterprise defaults, regulated-service runbooks, and wrapper documentation are complete, live use must be restricted to:

```text
read-only checks
status/reporting
backup verification
deployment preflight
explicitly approved maintenance pilot classes
```

## Policy-root warning

Operators must not have to guess whether the active system policy tree is `/etc/queuebash/policies.d`; `/etc/bashqueues/policies.d` is legacy/migration-only and must not silently become active. These hospital profiles use the canonical project policy examples under `policies.d/enterprise/` and require any installer/wizard output to report the active system policy root loudly before live use.

## Read-only hospital profile

`policies.d/enterprise/hospital-live-readonly-default.env.example` is the safe default for early live exposure. It allows inspection only and denies execution, mutation, live cloud changes, secret delivery, break-glass delivery, and external AI provider calls by default.

Allowed action families:

```text
status
list
show
explain
audit-read
report-read
backup-verify
preflight-readonly
```

Blocked action families:

```text
submit
run
worker-start
remote-mutation
cloud-apply
secret-deliver
break-glass-deliver
policy-edit
class-edit
```

Approval-required action families:

```text
none; switch to approved-maintenance profile for tightly governed maintenance
```

## Approved-maintenance hospital profile

`policies.d/enterprise/hospital-live-approved-maintenance-default.env.example` is for controlled maintenance pilots only. It still denies broad execution and live mutation by default, but permits named maintenance classes after dual-control approval and bounded evidence.

Approved maintenance must record:

```text
change ticket
approver identity
class name
purpose
maintenance window
secret policy decision
break-glass decision if used
rollback command or procedure
audit evidence path
```

## Secrets and break-glass posture

The hospital profiles preserve the Bob17 secrets rules:

```text
secret values never appear in JSON, logs, scratchpad, command lines, or ordinary environment variables by default
file delivery is preferred when delivery is explicitly approved
break-glass is refused by default
break-glass requires signed/dual authorisation, short TTL, reason, ticket, audit event, and redacted evidence
```

## Verification commands

A live pilot pack must show these checks before handoff:

```bash
bash -n queuebash.sh
bash -n tests/hospital_live_safe_mode_static.sh
bash tests/hospital_live_safe_mode_static.sh
python3 tests/hospital_live_safe_mode_json_contract_static.py
queue dev test qbtest --file queuebash.sh --function _queue_now --json
```

## Non-goals

This package does not clear broad live hospital job execution. It does not change the policy-root namespace, install live system files, call cloud providers, deliver secrets, or add runtime enforcement. It adds documented profiles and tests so a future Bob15 merge has a clear enterprise safe-mode baseline.


## 0.18.111 carry-forward completion

The Rupert carry-forward set now includes all four enterprise default profiles: `small-team-dev-default`, `government-project-test-default`, `hospital-live-readonly-default`, and `hospital-live-approved-maintenance-default`. The regulated-service live pilot runbook is `docs/REGULATED_SERVICE_RUNBOOK.md`. The AI policy gate fixture smoke has a bounded stage-summary wrapper at `tests/ai_policy_gate_fixture_stage_smoke.sh`; the older comprehensive smoke remains available for detailed coverage.

## Enterprise profile verify fixture

The fixture-only provider can be run without sourcing hospital profile code:

```bash
providers.d/enterprise/enterprise_profile_verify.sh --profile hospital-live-readonly-default --json
```

It emits `queuebash.enterprise_profile_verify.v1` evidence for pilot-review checks only.

## Public verification surface

Hospital profiles should be checked through the same public command named in the profile examples:

```bash
queue enterprise validate-profile hospital-live-readonly-default --json
queue enterprise validate-profile hospital-live-approved-maintenance-default --json
```

The command delegates to the bundled fixture verifier and returns `queuebash.enterprise_profile_verify.v1`. It is evidence-only and must not be treated as broad live clearance.



Enterprise validation command note:

`queue enterprise list-profiles --json`, `queue enterprise validate-profile PROFILE --json`, and `queue enterprise verify-maintenance --request FILE --json` are validation/evidence commands only. Bundled `policies.d/enterprise/*.env.example` files remain inert until deliberately copied, edited, validated, and installed through an explicit site-controlled activation process. These commands do not activate policy, grant live clearance, deliver secrets, or modify system state.
