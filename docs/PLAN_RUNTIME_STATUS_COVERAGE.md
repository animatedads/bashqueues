# Queue Plan Runtime/Status Coverage

Bob24 runtime/status coverage treats provider SDK snippets, exported API JSON,
CLI output, copied status payloads, and remote scheduler exports as evidence only.
`queue plan` must never poll live systems, load credentials, fetch logs, submit jobs,
or mutate provider resources.

## Boundary

`queue plan status PATH [--json]` recognises exported plan/job/status facts and
normalises them into `queue.control_plan.v1` reviewable `status_sources`.

It does not run:

- Azure, AWS, GCP, OCI, IBM, Alibaba, Huawei, or Tencent SDK calls
- Kubernetes, Slurm, HTCondor, systemctl, crontab, or scheduler CLI commands
- WinRM, SMB/RPC, WMI, Impacket, REST, GraphQL, or Airflow/Prefect/Dagster clients
- credential loading, secret reads, log retrieval, job submission, or provider mutation

## Multi-cloud families

Recognised exported runtime/status families include:

- Azure Logic Apps, Functions, WebJobs, Automation, Batch, Container Apps Jobs,
  SQL Elastic Jobs, and Azure DevOps Pipelines
- AWS Batch-related evidence, Step Functions, EventBridge Scheduler, Lambda,
  ECS tasks, Glue jobs, and CodePipeline
- GCP Cloud Batch-related evidence, Workflows, Cloud Tasks, and Cloud Run Jobs
- OCI Resource Scheduler, OS Management Hub work requests, Data Flow, DevOps
  deployments, and generic Work Requests
- IBM Code Engine and watsonx.ai, watsonx.data, and watsonx governance/OpenScale jobs
- Alibaba E-HPC, Batch Compute, and Serverless Workflow
- Huawei Batch/Volcano-style jobs and FunctionGraph workflows
- Tencent Batch and TKE task-style container jobs

## In-house tiers

The same static exported-fact boundary applies to in-house tiers:

- cron plan/status exports, preserving existing bashqueues cron semantics
- systemd timer exports
- Windows Task Scheduler exports gathered outside queue plan via WinRM/SMB/RPC
- Celery registered/active/scheduled task snapshots
- RQ queue/worker/registry snapshots
- APScheduler job-store snapshots
- Slurm `squeue`/`scontrol` exports
- HTCondor ClassAd/Schedd exports
- Kubernetes Job/CronJob exported API payloads
- Volcano batch/PodGroup exported CRD payloads
- Airflow REST API DAG/DAG-run exports
- Prefect deployment/flow-run exports
- Dagster GraphQL repository/run exports

## Policy requirements

Every runtime/status source receives an export-review policy requirement. The
policy family identifies whether the source is cloud runtime, local automation,
python queue runtime, HPC runtime, Kubernetes runtime, workflow runtime,
AI governance, or remote Windows scheduler evidence.

Cron remains special: runtime/status recognition must bridge to existing
bashqueues cron support and must not create a duplicate scheduler.
