# bashqueues FinOps and Legal Governance

Introduced in 0.17.77.

This release adds two governance rails without putting slow API calls or heavy
math in the worker hot path.

## FinOps rail

`bin/queue-finops-analyze` reads:

```text
$QUEUEBASH_ROOT/streams/finops.pricing.jsonl
```

It writes, atomically:

```text
$QUEUEBASH_ROOT/streams/finops.health
/var/tmp/queuebash_pricing_<region>_<instanceType>.txt
```

The existing `finops:spot_price_below` asset reads the price cache. The new
`finops:anomaly_free` asset reads the health file.

Example class asset:

```bash
queue_class_shared_asset finops anomaly_free _ block_on=error missing=ok
queue_class_shared_asset finops spot_price_below 0.045 instance_type=e2-standard-4 region=europe-west3
```

`missing=ok` is useful for non-critical cost rails. Use `missing=block` for
fail-closed sites.

## Legal rail

Legal checks are registry-backed. They do not trust a user-provided
`JOB_LEGAL_CLASS` as the authority.

Registry format:

```text
id  legal_class  retention_until  jurisdiction_scope  destructive_allowed  export_allowed
```

Example:

```text
dataset:case-123  LITIGATION_HOLD  2031-01-01  UK_DPA  0  1
```

Class asset examples:

```bash
queue_class_shared_asset legal retention_respected dataset:case-123 effect=destructive registry_file=/etc/bashqueues/legal_registry.tsv
queue_class_shared_asset legal jurisdiction_allowed dataset:case-123 worker_jurisdiction=UK_DPA registry_file=/etc/bashqueues/legal_registry.tsv
```

Effects treated as destructive include:

```text
destructive delete remove erase archive prune purge write migration migrate
```

Export effects include:

```text
export extract egress transfer
```

A registry file under `$QUEUEBASH_ROOT` is refused by default. Use
`allow_user_registry=1` only for tests and development. Production registries
should be root/site controlled, normally under `/etc/bashqueues`.

## Not included yet

0.17.77 deliberately does not add cryptographic legal tokens. That should be a
later step using the existing queue key/signing mechanisms, not a pretend crypto
variable.
