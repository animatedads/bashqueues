# Enterprise deployment recipe

This recipe describes a safe, inert-by-default enterprise deployment path. It is a recipe for validation and staged rollout, not an automatic activation script.

## Safety posture

Enterprise templates ship as `.env.example` files on purpose:

```text
policies.d/enterprise/small-team-dev-default.env.example
policies.d/enterprise/government-project-test-default.env.example
policies.d/enterprise/hospital-live-readonly-default.env.example
policies.d/enterprise/hospital-live-approved-maintenance-default.env.example
```

The suffix means the profile is a template. It must not be loaded automatically, must not become live by accident, and must be copied/adapted by an operator before use.

## Phase 1: inspect the package

```bash
source ./queuebash.sh
queue version --json
queue policy paths --json
queue policy status --json
queue enterprise list-profiles --json
```

Confirm that examples report `active=false` and `activation_supported=false`.

## Phase 2: validate inert examples

```bash
queue enterprise validate-profile small-team-dev-default --json
queue enterprise validate-profile government-project-test-default --json
queue enterprise validate-profile hospital-live-readonly-default --json
queue enterprise validate-profile hospital-live-approved-maintenance-default --json
```

Validation is evidence-only. It must not install policy, grant clearance, or deliver secrets.

## Phase 3: create a site policy outside the source tree

Copy an example to a controlled site-policy workspace, then edit site-specific values:

```bash
mkdir -p ./site-policy-review
cp policies.d/enterprise/hospital-live-readonly-default.env.example \
  ./site-policy-review/hospital-live-readonly-default.env
```

Required review fields include allowed actions, blocked actions, approval-required actions, log location, secret location, verification command, approver identity, ticket reference, and rollback owner.

## Phase 4: verify maintenance evidence

Use evidence-only verification before any approved maintenance pilot:

```bash
queue enterprise verify-maintenance --request examples/enterprise/maintenance-request.example.json --json
```

The verifier must preserve:

```text
live_clearance_granted=false
system_modified=false
```

## Phase 5: install only through an explicit site process

The first implementation intentionally does not provide `queue enterprise enable-profile`. Activation belongs in a guarded site-specific change process with human approval, backup, rollback, and audit capture.

A site process should record:

```text
active policy root
source template
edited site-policy file
diff/review reference
approver
maintenance window
audit/log path
rollback command
post-change verification output
```

## Phase 6: post-change verification

After a deliberate site process changes active policy, re-run:

```bash
queue policy paths --json
queue policy status --json
queue enterprise list-profiles --json
queue health
```

If policy paths disagree or the legacy policy root appears active unexpectedly, stop and roll back.
