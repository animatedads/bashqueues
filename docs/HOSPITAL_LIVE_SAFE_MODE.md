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

Operators must not have to guess whether the active system policy tree is `/etc/bashqueues/policies.d` or `/etc/queuebash/policies.d`. This Bob17 package does not change installer/wizard code; that is a P0 Bob23 operational clarity task. These hospital profiles use the canonical project policy examples under `policies.d/enterprise/` and require any installer/wizard output to report the active system policy root loudly before live use.

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

## Fixture profile verifier

Until a future command-router package wires a first-class `queue enterprise verify-profile` command, the hospital profile examples include a fixture-only verifier:

```bash
providers.d/enterprise/enterprise_profile_verify.sh --profile hospital-live-readonly-default --json
providers.d/enterprise/enterprise_profile_verify.sh --profile hospital-live-approved-maintenance-default --json
```

The verifier parses the example policy files as data rather than sourcing them as shell. It checks that the hospital profiles keep policy-root reporting explicit, disable external AI providers, disable secret environment delivery, deny secret values in JSON, require `no-secret-env` runtime posture, and preserve the read-only versus approved-maintenance distinction.

The verifier is deliberately not a live enablement path. Its JSON reports:

```text
schema: queuebash.enterprise_profile_verify.v1
mode: fixture-only
live_clearance_granted: false
system_modified: false
```

Future installer or command-router work may wrap this helper, but must not imply broad hospital live clearance merely because a fixture profile verifies.
