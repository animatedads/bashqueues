# Distributed Framework legal and compliance notes

`distributed_framework` fixtures must not include secrets, live credentials, customer data, personal data, export-controlled payloads, or real account identifiers. Live checks are out of scope for this fixture-first contract and must be added only behind explicit policy, audit, and reviewer acceptance.

Compliance-relevant facts should remain explicit JSON fields so downstream policy can fail closed.
