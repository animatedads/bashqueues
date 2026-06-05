# Queue plan collector contracts

`queue plan collectors PATH [--json]` emits `queue.plan.collectors.v1`.

This command documents how plan and job/runtime evidence would have to be collected by separate, policy-gated exporters. It does not collect anything itself. The contract boundary is: no SDK/API/CLI/WinRM/SMB/RPC/REST/GraphQL/Kubernetes API calls from `queue plan`.

## Boundary

`queue plan collectors` is a contract/report command only. It must not:

- import provider SDKs
- load credentials
- call cloud APIs
- run CLIs such as `aws`, `az`, `gcloud`, `oci`, `kubectl`, `squeue`, `systemctl`, `crontab`, or `schtasks`
- open WinRM, SMB, RPC, REST, GraphQL, Kubernetes API, Redis, broker, scheduler daemon, or workflow API connections
- tail logs
- submit jobs
- mutate providers
- create a parallel cron scheduler

Collectors, if built later, must be separate commands with explicit policy gates. Their only acceptable output for Bob24's lane is inert exported evidence files consumed by:

```text
queue plan status PATH --json
queue plan sources PATH --json
queue plan evidence PATH --json
```

## Plan versus job evidence

A collector contract separates:

```text
plan_sources: static definitions, schedules, DAGs, manifests, runbooks, task definitions
job_sources: exported runtime state, run history, queue depth, worker state, work requests, pod/job status, build/deployment status
```

## Policy gates

All collectors require `QUEUE_PLAN_COLLECTOR_REVIEW`. Cloud and cloud-workflow collectors also require `CLOUD_WORKFLOW_POLICY_REVIEW`. Watsonx and similar AI governance surfaces additionally require AI governance review. Cron-related collectors must preserve the existing bashqueues cron bridge and must not create an alternate scheduler path.

## Supported contract families

The initial contract matrix covers Azure, AWS, GCP, OCI, IBM watsonx, Alibaba Cloud, Huawei Cloud, Tencent Cloud, Windows Task Scheduler, local cron/systemd, Celery, RQ, APScheduler, Slurm, HTCondor, Kubernetes, Volcano, Airflow, Prefect, and Dagster evidence sources.
