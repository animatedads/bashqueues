# Key Value Store legal/compliance notes

This provider family is fixture-first and no-live by default. It is suitable for offline contract testing and documentation backfill only. Regulated environments should require explicit approval before any future live-read package is enabled. Mutation remains out of scope for Bob29 service coverage.

Non-goals: table-create, table-delete, item-put, item-delete, capacity-mutation, backup-restore, stream-enable, queue-dispatch-refactor.
