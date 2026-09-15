# Search Service legal/compliance notes

This provider family is fixture-first and no-live by default. It is suitable for offline contract testing and documentation backfill only. Regulated environments should require explicit approval before any future live-read package is enabled. Mutation remains out of scope for Bob29 service coverage.

Non-goals: domain-create, domain-delete, index-create, index-delete, document-index, document-delete, query-execute, snapshot-restore, queue-dispatch-refactor.
