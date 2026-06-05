# Native queue plan format

The native bashqueues plan format is `queue.plan.v1`. It is the most complete and readable way to describe a bashqueues control plan, but it is not a privileged execution path. It is parsed by the `bashqueues-plan` adapter and normalized to `queue.control_plan.v1` like every other source.

## Minimal example

```yaml
schema: queue.plan.v1
name: hospital-test-rollout
classes:
  - name: DATABASE_MIGRATION
    max_concurrent: 1
    restrictions:
      network:
        egress:
          - database.internal:5432
      filesystem:
        readonly_root: true
      identity:
        require: db-migration-runner
    approval:
      required: true
      reason: database schema change
  - name: APP_ROLLOUT
    max_concurrent: 4
    depends_on:
      - DATABASE_MIGRATION
    restrictions:
      network:
        ingress: internal
        egress:
          - database.internal:5432
jobs:
  - name: migrate-db
    class: DATABASE_MIGRATION
    command: ./migrate.sh
    timeout: 20m
  - name: rollout-app
    class: APP_ROLLOUT
    command: ./deploy.sh
    depends_on:
      - migrate-db
```

## Required semantics

- classes and restrictions must be created before jobs are allowed into those classes;
- secret entries are references only, never values;
- public gateways require explicit approval gates unless local policy has a safe exception;
- destructive or privileged controls default to `needs_review` or `unsafe_refused`;
- a native plan must produce the same explain/build/apply flow as every foreign plan.
