# Queue plan format market coverage

Bob24 coverage goal: avoid a Kubernetes-only importer. `queue plan` must be designed around the full market of current and legacy operational plan formats.

## Coverage matrix

| Family | Current formats | Legacy / compatibility formats | Key controls | queue plan mapping |
| --- | --- | --- | --- | --- |
| Native bashqueues | `queue.plan.v1` YAML/JSON | future versioned aliases | classes, restrictions, assets, jobs, gateways, dependencies | reference adapter to `queue.control_plan.v1` |
| Kubernetes / cloud-native | Pod, Job, CronJob, Deployment, Service, NetworkPolicy, Gateway, HTTPRoute, ResourceQuota, LimitRange, ServiceAccount, Role, RoleBinding YAML/JSON | older `extensions/*`, `v1beta1`, Helm-rendered YAML, Kustomize output, OpenShift templates/routes/build configs | workload, identity, resources, network, gateway, quotas | classes, job templates, restrictions, gateways, identities, dependencies |
| AWS | AWS Batch JobDefinition, JobQueue, ComputeEnvironment, SchedulingPolicy, ECS task definition, EKS manifests, CloudFormation YAML/JSON, CDK output | older Batch/CloudFormation shapes, CLI JSON payloads | queue, compute environment, job definition, IAM role, timeout, retry | class, asset pool, job template, identity restriction, retry/timeout policy |
| Azure / Microsoft | Azure Batch pool/job/task, ARM JSON, Bicep, AKS manifests, Azure Pipelines YAML, managed identity/RBAC, NSG/Application Gateway controls | classic ARM templates, older Azure DevOps build/release fragments | pools, tasks, pipeline stages, managed identity, network gateways | asset pool, class, workflow, identity restriction, gateway/network restriction |
| Google Cloud | Google Cloud Batch JSON/YAML, GKE, Kueue, JobSet, Cloud Build YAML, Terraform | Deployment Manager YAML/JSON, older GKE manifests | allocation policy, batch jobs, quotas, job sets, service account | class, job template, quota/fair-share/admission, workflow bundle |
| Oracle OCI | OKE manifests, Data Flow application/run JSON, Data Science Job/Job Run JSON, Resource Manager Terraform, VCN/security/gateway JSON | OCI CLI JSON payloads, older Terraform modules | Spark/ML runs, compartments, identity, object storage, VCN gateways | data/ML class, object-storage asset, identity/network restrictions |
| IBM Cloud | Code Engine jobs, IBM Kubernetes Service, Tekton, Terraform, VPC ACL/security groups, IAM access policies | Cloud Foundry manifest style where encountered, older CLI exports | serverless batch, Kubernetes workloads, IAM, network ACLs | serverless batch class, K8s plan, workflow, identity/network restrictions |
| HPC schedulers | Slurm `sbatch`, OpenPBS/PBS Pro, HTCondor submit, Flux jobspec YAML | Torque, SGE/Grid Engine, LSF, DAGMan, scheduler migration scripts | partition/queue, account, QOS, walltime, memory, CPU, GPU, arrays, dependencies | class, resource restrictions, fanout, dependency graph, accounting policy |
| General orchestrators | Nomad HCL, systemd service/timer and cron | init-script era service wrappers | job/group/task, resources, services, periodic schedules | class/workflow/job template, service/gateway exposure, schedule |
| CI/CD and workflow | Argo Workflow, Tekton Pipeline, Airflow DAG, GitHub Actions, GitLab CI, Jenkinsfile | older Jenkins scripted pipeline, legacy CI YAML | stages/tasks/DAG, secrets, permissions, approvals, runners | workflow graph, job templates, identity/secret restrictions, approval gates |
| IaC meta-formats | Terraform/OpenTofu HCL, Pulumi YAML/output, CloudFormation, ARM/Bicep, OCI Resource Manager | legacy generated vendor templates | infrastructure and control intent | extract declared class/asset/gateway/identity facts; do not provision |
| Script behaviour | POSIX shell, Bash, maintenance/deploy/backup/test scripts | legacy init/deploy wrappers, vendor install scripts | common command patterns, pre-flight tests, filesystem/network/cloud/database operations, privilege changes | static behavioural plan inference: class, restrictions, dependencies, assets, review gates |

## Current plus legacy must be explicit

The documentation and fixtures should name both current and legacy forms even when early adapters only scan a subset. This prevents the normalized schema from assuming every plan is Kubernetes YAML.

## First fixture obligations

Each family must have at least one fixture path under `fixtures/plan/`, even if the initial adapter state is `recognized_pending_mapper`. Static tests should verify the inventory so future work does not drop legacy families accidentally.

## Script behaviour coverage

The `script-behaviour` adapter is a bridge for ordinary operational scripts. It should recognize deterministic checks and command patterns without executing the script. This is intentionally different from a shell runner: it converts static behavioural evidence into a plan candidate, preserving unknown and dangerous constructs as review/refusal findings.

Initial scope: `.sh`, `.bash`, executable text with a shell shebang, and conservative POSIX/Bash syntax scans. Later scope may include PowerShell, Python task scripts and Makefiles only through equally static rules.

## DGX / GPU cloud-workflow coverage note

DGX and other GPU fleet plans are covered as policy-sensitive cloud/workflow plans. They may appear as Kubernetes GPU requests, Slurm/PBS GPU directives, Nomad resources, cloud batch accelerator fields, or native bashqueues classes. `queue plan` must preserve those facts and emit a DGX/cloud/workflow policy hook rather than treating GPU only as a numeric resource.
