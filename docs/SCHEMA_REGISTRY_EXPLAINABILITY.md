# Schema Registry explainability notes

The schema_registry provider family explains why schema and compatibility evidence was classified as allow or deny in fixture evidence.

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
