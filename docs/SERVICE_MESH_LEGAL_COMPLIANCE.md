# Service Mesh legal and compliance notes

This provider family is fixture-first and advisory-only.

Compliance boundaries:

- No live provider calls in default tests.
- No credential collection.
- No secret values in fixtures, logs, scratchpad, or JSON output.
- No customer data export.
- No external state mutation.
- No provisioning or destructive operation.

Regulated environments should require explicit approval before any future live-read package is enabled. Mutation remains out of scope for Bob29 service coverage.
