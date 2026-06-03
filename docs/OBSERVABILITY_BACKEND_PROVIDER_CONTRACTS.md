# Observability Backend provider contracts

This fixture-first provider family publishes normalized JSON facts for advisory observability endpoint, metric, trace, signal, and alert facts without scraping or mutating telemetry backends.

## Commands

```text
providers.d/observability_backend/observability_backend_provider.sh detect
providers.d/observability_backend/observability_backend_provider.sh signal explain
providers.d/observability_backend/observability_backend_provider.sh metric explain
providers.d/observability_backend/observability_backend_provider.sh trace explain
providers.d/observability_backend/observability_backend_provider.sh alert explain
```

## Safety contract

- Fixture-first by default.
- No live credentials for tests.
- No provider output is shell.
- No provisioning, mutation, or queue dispatch refactor.
- JSON facts are advisory evidence only.

## Non-goals

- live-scrape
- telemetry-write
- trace-export
- alert-mutation
- job-runtime-mutation
