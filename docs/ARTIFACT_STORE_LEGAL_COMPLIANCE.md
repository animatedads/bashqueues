# Artifact Store legal and compliance notes

The artifact store provider family is fixture-first. Default tests require no live credentials and do not call external services.

Compliance boundaries:

- no secrets in docs, fixtures, scratchpad, JSON output, or zips
- no data/artifact payload reads in default fixtures
- no live provider mutation
- no export-control or region acceptance claims
- provider facts remain advisory until consumed by explicit policy gates
