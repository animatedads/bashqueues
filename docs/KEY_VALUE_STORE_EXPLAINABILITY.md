# Key Value Store explainability

`key_value_store` explain commands expose bounded, fixture-backed facts for inventory and review. Output must include `schema`, `provider_family`, `provider`, `check`, `decision`, `fail_closed`, `mutated`, and `provider_output_is_shell`.

The family is advisory. It should help an operator understand current coverage and policy posture without reading live data, sending requests, changing state, or returning shell commands.
