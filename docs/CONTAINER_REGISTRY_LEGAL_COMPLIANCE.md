# Container registry legal and compliance notes

Fixture-first container registry coverage is not live compliance acceptance.

Before a container registry provider can be promoted beyond fixture-first status,
it needs evidence for identity, registry tenancy, region/replication, image
provenance, SBOM/signature enforcement, vulnerability thresholds, retention,
legal hold, audit logging, export-control posture, and cost/egress policy.

This package deliberately does not pull, push, delete, or create registry
resources. It exposes normalized fixture facts only.
