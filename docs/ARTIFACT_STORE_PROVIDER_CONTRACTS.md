# Artifact Store provider contracts

Bob14 service-coverage provider family for artifact store systems.

## Contract

The provider helper is fixture-first and emits normalized JSON facts only. It does not perform live provider calls by default, does not mutate provider state, does not return shell commands, and does not grant authority.

Supported fixture commands:

```text
detect, artifact explain, provenance explain, retention explain, and integrity explain
```

## Non-goals

This package does not implement upload, download, delete, promote, retention mutation, signature generation, or queue scheduling.

## Safety

Provider output is advisory evidence for policy/class gates. It is not executable shell and must not be treated as acceptance, access approval, or a scheduler decision.
