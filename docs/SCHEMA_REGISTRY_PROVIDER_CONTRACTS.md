# Schema Registry provider contracts

Bob14 service-coverage provider family for schema registry systems such as Confluent Schema Registry, AWS Glue Schema Registry, Azure Event Hubs schema registry, Apicurio, and file-backed fixtures.

## Contract

The provider helper is fixture-first and emits normalized JSON facts only. It does not perform live provider calls by default, does not mutate provider state, does not return executable commands, and does not grant authority.

Supported fixture commands:

```text
detect, registry explain, schema explain, compatibility explain, governance explain
```

## Non-goals

This package does not implement schema-register, schema-delete, compatibility-mutation, subject-create, access-grant, queue-dispatch-refactor.

## Safety

Provider output is advisory evidence for policy/class gates. It is not executable and must not be treated as acceptance, access approval, or a scheduler decision.
