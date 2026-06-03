# Feature Store legal and compliance notes

Fixture-first feature store coverage is not live legal approval. These files are contract fixtures for documentation, static validation, and JSON shape testing.

Compliance boundaries:

- no credentials are required for default tests
- no protected values are stored in fixtures
- no live tenant, region, account, workspace, vault, project, cluster, bucket, table, or dataset is queried
- no export-control, privacy, retention, residency, or customer-data approval is implied
- promotion beyond fixture-first requires deeper identity, region, cost, legal/compliance, export-control, explainability, fixture, JSON, and operational test coverage

Reviewer note: provider-family presence is not first-tier parity.
