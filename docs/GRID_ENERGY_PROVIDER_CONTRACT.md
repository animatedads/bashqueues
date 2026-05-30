# Grid Energy Provider Contract

Provider path:

```text
providers.d/grid_energy/grid_energy_provider.sh
```

Commands:

```bash
providers.d/grid_energy/grid_energy_provider.sh explain --json
providers.d/grid_energy/grid_energy_provider.sh evaluate --cache FILE --json [policy options]
```

Policy options:

```text
--market NAME
--zone ZONE
--max-price-per-kwh VALUE
--max-carbon-gco2-kwh VALUE
--require-negative-price
--max-age-seconds SEC
```

Decision schema:

```json
{
  "schema": "queuebash.grid_energy.decision.v1",
  "decision": "allow",
  "reason": "grid_energy_policy_pass",
  "live_call_performed": false,
  "mutation_performed": false,
  "advisory_only": true
}
```

Required safety properties:

- no live API calls in default tests;
- no credentials required;
- no cloud provisioning/destruction;
- no queue dispatch refactor;
- no industrial-control writes;
- fail closed on missing/stale/malformed cache data;
- emit bounded JSON decisions for audit and explainability.
