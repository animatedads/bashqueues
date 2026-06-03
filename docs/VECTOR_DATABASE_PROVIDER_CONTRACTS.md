# Vector database provider contracts

Status: fixture-first provider-family contract.

This provider family supplies normalized JSON facts about vector collections,
indexes, embedding policy, and retention evidence. It does not run retrieval,
query embeddings, perform live embedding, create indexes, delete vectors, or
change queue scheduling.

Commands:

```text
providers.d/vector_database/vector_database_provider.sh detect
providers.d/vector_database/vector_database_provider.sh collection explain
providers.d/vector_database/vector_database_provider.sh index explain
providers.d/vector_database/vector_database_provider.sh embedding-policy explain
providers.d/vector_database/vector_database_provider.sh retention explain
```

Default tests use `QUEUEBASH_VECTOR_DATABASE_FIXTURE_DIR`. Live reads are
reserved for later gated packages. Provider output is advisory evidence only and
must never return shell commands.
