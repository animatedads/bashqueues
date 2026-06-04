# Data Quality explainability notes

The data_quality provider family explains why ruleset, expectation, profile, and quality-result evidence was classified as allow or deny in fixture evidence.

Every fixture result must include:

- schema
- provider_family
- provider
- decision
- reason
- fail_closed
- mutated=false
- provider_output_is_shell=false

The helper must expose bounded facts only. Any future live integration must keep provider-specific evidence separate from queue acceptance and must remain gated by policy/ACL review.
