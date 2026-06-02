# Queue class anomaly policy

Class inference should be conservative.

Do not block merely because a requested class differs from history.  Escalate
when deterministic evidence suggests a weaker class may bypass security,
assets, audit, network, secret handling, legal, or corporate controls.

Mismatch families:

```text
resource_downgrade
security_downgrade
asset_mismatch
cost_mismatch
cloud_mismatch
ai_mismatch
unknown_shift
```

This first package reports `class_mismatch` only.  Later packages can enrich it
by comparing class envelopes and asset/capability history.

## Policy references

Brokerage policy decisions should link to applicable controls when available:

```text
corporate policy id
regulatory framework id
jurisdiction / sovereignty policy
export-control policy
retention / legal-hold policy
validation status
```

These links support audit and explainability.  They do not by themselves certify
that a workload is compliant.
