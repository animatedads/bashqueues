# Queue Plan Extraction Source Contract

Bob24 continuation for `queue plan` plan/job evidence.

## Purpose

`queue plan` now distinguishes between two related inputs:

- **Plans**: static configuration, definitions, schedules, DAGs, queue definitions, task definitions, manifests, scheduler directives, service/timer units, runbook definitions, cloud workflow definitions, pipeline definitions.
- **Jobs**: exported runtime state, execution history, active work, queue depth, run status, task status, worker state, work requests, pod/job status, build/deployment status.

The command surface consumes both as supplied files, but it does **not** collect them itself.

## Command

```sh
queue plan sources PATH [--json]
```

The command explains which source contracts were inferred from the input and how a separate exporter would have produced them. It is intentionally static.

## Non-negotiable boundary

`queue plan` must not:

- call cloud SDKs or CLIs
- load credentials or tokens
- open WinRM, SMB, RPC, SSH, REST, GraphQL or Kubernetes API sessions
- tail system logs
- connect to Redis, brokers, Airflow, Prefect, Dagster, Celery, RQ, HTCondor or Slurm daemons
- submit, stop, retry, mutate or log-fetch jobs
- duplicate the existing bashqueues cron scheduler path

`queue plan` may only parse plan/job evidence already exported into files.

## Contract shape

Each recognised adapter can emit a `queue.plan.sources.v1` contract:

```json
{
  "adapter": "windows-task-scheduler",
  "provider": "windows",
  "family": "remote_scheduler_status",
  "mode": "static_file_only",
  "plan_sources": ["Get-ScheduledTask JSON export", "schtasks CSV/XML export"],
  "job_sources": ["Get-ScheduledTaskInfo JSON export", "Task Scheduler history export"],
  "extractor": "external_winrm_or_smb_rpc_exporter",
  "boundary": "queue plan must not open WinRM, SMB, RPC or use Windows credentials",
  "safe_to_collect_here": false
}
```

## Existing cron correction

Cron is special because bashqueues already has cron support.

Raw crontab and cron runtime exports may be scanned and explained, but execution must remain with the existing bashqueues cron subsystem. Bob24 must not create a parallel scheduler.

## Current source families

- local cron plans and cron log exports
- systemd service/timer definitions and timer status exports
- Windows Task Scheduler exports from WinRM/SMB/RPC tooling
- Celery, RQ and APScheduler exported runtime facts
- Slurm and HTCondor exported status facts
- Kubernetes Jobs/CronJobs and Volcano exported status facts
- Airflow, Prefect and Dagster exported workflow/run facts
- Azure Logic Apps, Functions, WebJobs, Automation, Container Apps Jobs, SQL Elastic Jobs and DevOps exports
- AWS Batch/Step Functions/EventBridge/Lambda/ECS/Glue/CodePipeline exports
- GCP Batch/Workflows/Cloud Tasks/Cloud Run Jobs exports
- OCI Resource Scheduler, OS Management Hub, Data Flow, DevOps and Work Request exports
- IBM Code Engine and watsonx.ai/data/governance exports
- Alibaba E-HPC, Batch Compute and Serverless Workflow exports
- Huawei Batch/FunctionGraph exports
- Tencent Batch/TKE Task exports

## Future collector rule

If a future Bob builds live collectors, they must be separate, policy-gated commands and must produce inert exported fact files for `queue plan`. They must not be hidden inside `queue plan scan`, `queue plan status` or `queue plan build`.
