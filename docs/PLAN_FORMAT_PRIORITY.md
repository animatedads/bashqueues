# Queue plan adapter priority

## Phase 1: foundational

- native bashqueues `queue.plan.v1`;
- Kubernetes YAML/JSON for Job, CronJob, NetworkPolicy and Gateway/API routing controls;
- Slurm `sbatch`;
- PBS/OpenPBS/PBS Pro/Torque `qsub`;
- HTCondor submit files;
- Flux jobspec YAML;
- existing cron integration view, delegating to the cron subsystem rather than replacing it;
- common script-behaviour static adapter for shell deployment, backup, migration, maintenance and test scripts.

## Phase 2: major cloud batch

- AWS Batch CloudFormation/API JSON;
- Azure Batch, ARM and Bicep;
- Google Cloud Batch, GKE Kueue and JobSet;
- OCI OKE/Data Science/Data Flow;
- IBM Code Engine.

## Phase 3: workflow/orchestration

- Argo Workflows;
- Tekton Pipelines;
- Nomad HCL;
- Airflow static DAG scan;
- GitHub Actions;
- GitLab CI;
- Jenkinsfile read-only scan.

## Phase 4: IaC extraction

- Terraform/OpenTofu;
- Pulumi YAML/output;
- general CloudFormation/ARM/Bicep/OCI Resource Manager extraction.

All phases are non-mutating until a later approved apply gate exists.
