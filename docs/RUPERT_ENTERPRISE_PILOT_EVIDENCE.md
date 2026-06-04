# Rupert enterprise pilot evidence

Rupert's 0.18.108 assessment is accepted as enterprise acceptance evidence, not as rejection and not as production clearance.

## Verdict

```text
0.18.108 is credible for dev/test pilot and controlled governed admin workflows.
It is not yet cleared for broad live hospital operations.
Live use should remain restricted to read-only/status/reporting and tightly approved maintenance classes until the operational blockers are fixed.
```

## Operational blockers to carry forward

```text
P0: resolve /etc/bashqueues versus /etc/queuebash policy namespace inconsistency
P1: split or bound long AI policy gate smoke tests
P1: add enterprise default policy profiles
P1: add live regulated-service runbook
P1: document shell-function versus installed-wrapper behaviour
```

## Bob17 scope from this evidence

Bob17 owns the hospital live safe-mode policy profile and the secrets/break-glass/live-maintenance control posture. Bob23 owns policy namespace consistency and shell-function versus installed-wrapper wording. Bob21 owns AI policy gate fixture-smoke boundedness. Bob15 merges only after clean delivery evidence.


## 0.18.111 carry-forward completion

The Rupert carry-forward set now includes all four enterprise default profiles: `small-team-dev-default`, `government-project-test-default`, `hospital-live-readonly-default`, and `hospital-live-approved-maintenance-default`. The regulated-service live pilot runbook is `docs/REGULATED_SERVICE_RUNBOOK.md`. The AI policy gate fixture smoke has a bounded stage-summary wrapper at `tests/ai_policy_gate_fixture_stage_smoke.sh`; the older comprehensive smoke remains available for detailed coverage.
