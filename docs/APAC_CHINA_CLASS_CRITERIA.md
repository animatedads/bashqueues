# APAC/China class criteria

These class templates are examples for future APAC/China provider integration. They are not live provisioning controls.

Class criteria should be explicit about:

- provider family and specific provider
- region/sovereignty expectations
- identity/auth posture
- network isolation expectations
- object storage / artifact handling
- audit/log evidence
- legal framework and data-transfer review posture
- cost/FinOps ceiling where applicable

High-assurance classes should fail closed when the provider cannot supply normalized facts. They should not silently accept unknown region, unknown account/project, missing audit evidence, or unvalidated data-transfer posture.
