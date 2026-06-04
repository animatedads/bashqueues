# Metadata Catalog explainability

The metadata catalog provider family explains why a fixture fact was allowed or denied using stable fields:

```text
schema
provider_family
provider
decision
fail_closed
mutated
provider_output_is_shell
reason or advisory facts
```

A denied or missing fixture response is fail-closed and includes remediation guidance. Advisory facts must remain separate from policy acceptance and runtime scheduling decisions.
