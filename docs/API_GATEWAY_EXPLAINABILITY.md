# API Gateway explainability

The `api_gateway` family records explicit `schema`, `provider_family`, `check`, `decision`, `evidence`, `fail_closed`, `live_api_used`, `mutated`, and `provider_output_is_shell` fields so operators can understand why a fixture-backed provider fact was accepted or denied.

Missing fixtures fail closed with a JSON denial and a remediation hint instead of attempting network discovery.
