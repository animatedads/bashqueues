# Metadata Catalog provider contracts

Bob14 service-coverage provider family for metadata catalog systems.

## Contract

The provider helper is fixture-first and emits normalized JSON facts only. It does not perform live provider calls by default, does not mutate provider state, does not return shell commands, and does not grant authority.

Supported fixture commands:

```text
detect, catalog explain, asset explain, lineage explain, and classification explain
```

## Non-goals

This package does not implement catalog mutation, data reads, access grants, tag writes, policy acceptance, or queue scheduling.

## Safety

Provider output is advisory evidence for policy/class gates. It is not executable shell and must not be treated as acceptance, access approval, or a scheduler decision.
