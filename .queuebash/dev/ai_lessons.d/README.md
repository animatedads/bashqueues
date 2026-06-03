# queue dev ai lesson records

Runtime lessons are stored here as one JSON file per lesson (`AIL-*.json`).
This directory-scanned layout is intentional: separate lesson files reduce
patch-stream collisions and allow a new AI session to load active lessons on
start without merging a shared monolithic lesson log.

Do not store secrets or raw long logs in lesson records.
