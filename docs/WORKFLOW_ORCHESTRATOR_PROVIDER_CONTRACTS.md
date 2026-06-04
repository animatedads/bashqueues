# Workflow Orchestrator provider contracts

## Purpose

Workflow orchestrator provider facts describe DAG/workflow metadata, schedules, dependencies, and governance controls for systems such as Airflow, Argo, Dagster, Prefect, or managed workflow services without starting or changing workflows.

## Safety boundary

This is a fixture-first advisory provider contract. It returns normalized JSON facts only. It must not make live calls by default, mutate provider state, provision resources, return shell commands, or change queue dispatch/scheduling.

## Commands

```text
providers.d/workflow_orchestrator/workflow_orchestrator_provider.sh detect
providers.d/workflow_orchestrator/workflow_orchestrator_provider.sh workflow explain
providers.d/workflow_orchestrator/workflow_orchestrator_provider.sh schedule explain
providers.d/workflow_orchestrator/workflow_orchestrator_provider.sh dependency explain
providers.d/workflow_orchestrator/workflow_orchestrator_provider.sh governance explain
```

## Schemas

```text
queuebash.workflow_orchestrator.detect.v1
queuebash.workflow_orchestrator.workflow.v1
queuebash.workflow_orchestrator.schedule.v1
queuebash.workflow_orchestrator.dependency.v1
queuebash.workflow_orchestrator.governance.v1
```

## Default fixtures

Default tests use `tests/fixtures/workflow_orchestrator/` through `QUEUEBASH_WORKFLOW_ORCHESTRATOR_FIXTURE_DIR`. No credentials are required.
