# Load Balancer legal and compliance notes

`load_balancer` coverage is deliberately no-live and fixture-first. It does not collect credentials, export secrets, inspect payload bodies, mutate provider resources, or perform traffic/routing changes.

Default tests use offline fixtures only. Any later live-read implementation must be explicitly gated, read-only, auditable, and must preserve normalized JSON facts without shell command output.
