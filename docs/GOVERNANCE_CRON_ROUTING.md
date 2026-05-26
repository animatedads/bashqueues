# Governance cron routing

`bashqueues-cron-class-selector.py` can now use cron metadata to select a
policy-compliant class instead of requiring a crontab to hard-code a provider.

Supported metadata directives in user or system crontabs:

```cron
#jurisdiction GDPR
#classification Sensitive
#tags gdpr,compute
#cost-budget 0.05
* * * * * python3 process.py
```

Equivalent environment-style directives are also accepted:

```cron
BASHQUEUES_JURISDICTION=GDPR
BASHQUEUES_CLASSIFICATION=Sensitive
BASHQUEUES_TAGS=gdpr,compute
BASHQUEUES_COST_BUDGET=0.05
```

When governance metadata is present the selector reads
`policies.d/legal-registry/default.env` and chooses an available class such as
`CLOUD_GCP_GDPR`, `CLOUD_AZURE_GDPR`, or `CLOUD_COMPUTE_GDPR`. If
`QUEUEBASH_FINOPS_STATUS_JSON` or `/var/tmp/bashqueues_finops_status.json`
contains provider/region prices, the cheapest eligible route under the budget is
preferred.

If metadata is supplied but no compliant route can be found, the selector can
fail closed by returning `CRON_POLICY_BLOCKED`. The cron ticker passes
`--fail-closed` automatically when `#jurisdiction` or `#classification` is used.
The fail-closed class contains an impossible `path:exists` asset so the job does
not silently execute under a generic cron fallback.

The selector remains conservative: explicit `#class` still wins, and selected
classes must meet the cron minimum sandbox/seccomp policy or the ticker falls
back to the generated strict `cron_<hash>` class.
