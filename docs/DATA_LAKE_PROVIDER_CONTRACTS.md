# Data lake provider contracts

Status: fixture-first provider-family contract.

This provider family supplies normalized JSON facts about catalog presence,
dataset metadata, governance labels, and retention evidence. It does not query
real tables, read samples, create buckets, delete objects, change partitions, or
modify queue scheduling.

Commands:

```text
providers.d/data_lake/data_lake_provider.sh detect
providers.d/data_lake/data_lake_provider.sh catalog explain
providers.d/data_lake/data_lake_provider.sh dataset explain
providers.d/data_lake/data_lake_provider.sh governance explain
providers.d/data_lake/data_lake_provider.sh retention explain
```

Default tests use `QUEUEBASH_DATA_LAKE_FIXTURE_DIR`. Live reads are deferred to
later explicit packages and must remain read-only, gated, and auditable.

Contract check phrase: It does not query real tables.
