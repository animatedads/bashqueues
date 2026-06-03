# Model registry explainability

Model registry facts must explain why a model catalogue or model entry is usable
for a proposed governance decision.

Required explanation fields include:

- `model_id` or `catalog_id`
- `capabilities`
- `endpoint_class`
- `data_residency`
- `cost_tier`
- `validation_status`
- `decision`
- `reason`
- `fail_closed`
- `mutated`

The provider helper must never return shell commands. queuebash consumers may use
these facts for advisory or policy reasoning, but must not execute provider
output.
