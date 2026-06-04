# Data Quality provider contracts

Bob14 service-coverage provider family for data quality systems such as Great Expectations, Deequ/Soda-style checks, dbt test metadata, cloud data quality services, and file-backed fixtures.

## Contract

The provider helper is fixture-first and emits normalized JSON facts only. It does not perform live provider calls by default, does not mutate provider state, does not return executable commands, and does not grant authority.

Supported fixture commands:

```text
detect, ruleset explain, expectation explain, profile explain, result explain
```

## Non-goals

This package does not implement data-scan, data-sample-read, rule-write, expectation-mutate, quality-gate-acceptance, queue-dispatch-refactor.

## Safety

Provider output is advisory evidence for policy/class gates. It is not executable and must not be treated as acceptance, access approval, or a scheduler decision.
