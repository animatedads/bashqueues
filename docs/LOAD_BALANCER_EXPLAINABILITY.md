# Load Balancer explainability

The `load_balancer` provider helper produces small normalized JSON documents that explain detected capability, dependency, policy and safety posture. The documents are fixtures by default so tests can reason about service estates without credentials or live calls.

Each fact document includes `schema`, `provider_family`, `provider`, `check`, `decision`, `source`, `fail_closed`, `mutated`, `provider_output_is_shell`, `live_api_used`, and `credentials_required` fields.

The helper is advisory. It is intended for future admission, documentation, compliance, and dependency review surfaces, not for changing provider state.
