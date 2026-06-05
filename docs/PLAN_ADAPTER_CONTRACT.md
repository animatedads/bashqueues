# Queue plan adapter contract

A plan adapter is a source-specific parser/classifier that converts a supported input format into `queue.control_plan.v1`. It must not submit jobs, mutate cloud resources, execute arbitrary source code, fetch secrets, or apply generated controls.

## Required adapter outputs

Every adapter must emit:

```text
source.adapter
source.format
source.path
source.digest where available
source.native true/false
adapter.confidence
objects detected
normalized classes/restrictions/assets/gateways/identities/secrets/job_templates/workflows/dependencies
analysis.warnings
analysis.unsupported
analysis.needs_review
analysis.unsafe_refused
```

## Adapter boundary

Allowed:

- parse local YAML/JSON/HCL/directive files;
- classify source objects and directives;
- preserve source references and unknown fields;
- infer safe control-plan candidates;
- emit warnings/refusals/review gates;
- produce deterministic JSON suitable for tests.

Not allowed:

- live cloud API calls;
- credential discovery beyond explicit non-secret references;
- running shell snippets from imported plans;
- executing Airflow/Jenkins/Pulumi/Terraform source code;
- dereferencing secret values;
- applying firewall/IAM/gateway changes;
- submitting queue jobs as part of scan/build.

## Native and foreign plans

Native bashqueues YAML is implemented as an adapter called `bashqueues-plan`. It is the reference expression of the normalized model but must still flow through the same adapter/common-planner pipeline as Kubernetes, AWS Batch, Azure Batch, GCP Batch, OCI, IBM, Slurm, PBS, HTCondor, Nomad and CI/CD formats.

## Cron exception

Cron is not a normal foreign-plan adapter. bashqueues already has cron support, explain behaviour, privilege context, and user/system/all views. `queue plan` may expose cron through scan/explain/build, but cron parsing, privilege context, system/user separation, clearance behaviour and safety checks must remain aligned with the current cron subsystem.
## Script-to-plan adapter: normalized script behaviour

A common shell/script file can also be a source plan when it contains deterministic operational behaviour. Bob24 should treat this as a static adapter lane called `script-behaviour`, not as script execution.

The adapter goal is to infer a conservative `queue.control_plan.v1` from common, repeatable script patterns:

```text
shell or script source
  -> parse/static scan
  -> classify deterministic operations
  -> infer classes, assets, restrictions, dependencies and review gates
  -> preserve unmodelled commands as evidence
  -> refuse to execute or guess dynamic behaviour
```

This would allow an administrator to point `queue plan explain` at an ordinary deployment, backup, migration, test or maintenance script and receive a bashqueues operating model: what kind of class it implies, what resources it touches, what network/cloud/secret access it needs, what pre-flight checks it performs, and what should be blocked for review.

### Important boundary

The script adapter must not run the script, source the script, expand command substitution, call package/cloud tools, dereference variables from the live environment, or execute embedded Python/Perl/Ruby/Node fragments. It is a static behavioural normalizer only.

### Deterministic patterns to recognize

Common script checks are often stable enough to map:

- `set -e`, `set -u`, `set -o pipefail` -> safety posture evidence;
- `test`, `[ ... ]`, `[[ ... ]]`, `case`, simple `if` guards -> precondition dependencies;
- `command -v`, `which`, `type` -> binary/tool dependencies;
- `mkdir`, `install -d`, `touch`, `cp`, `mv`, `rsync`, `tar` -> filesystem assets and writable path restrictions;
- `chmod`, `chown`, `sudo`, `su`, `doas` -> privilege/review gates;
- `curl`, `wget`, `ssh`, `scp`, `rsync host:` -> network egress and remote-host dependencies;
- `psql`, `mysql`, `sqlite3`, `mongosh`, `redis-cli` -> database asset and credential restrictions;
- `aws`, `az`, `gcloud`, `oci`, `ibmcloud`, `kubectl`, `helm`, `terraform`, `tofu`, `pulumi` -> provider/control-plane assets and no-live review gates;
- `docker`, `podman`, `buildah`, `nerdctl` -> container runner/build class implications;
- `systemctl`, `service`, `crontab` -> host-service or schedule mutation review;
- `trap` -> cleanup/failure-policy evidence;
- bounded `for` lists and simple arrays -> fanout candidates;
- obvious order of commands -> dependency edge candidates.

### Script classification examples

```text
backup script
  -> BACKUP_JOB class
  -> filesystem/object-storage assets
  -> database/network dependencies if dump or upload commands appear
  -> secrets references only, never values

migration script
  -> DATABASE_MIGRATION class
  -> max_concurrent=1 candidate
  -> manual approval gate
  -> database credential and rollback-note review

deployment script
  -> DEPLOYMENT_ORCHESTRATION or SERVICE_ROLLOUT class
  -> cloud/kubernetes/provider-control assets
  -> gateway/network review where public exposure commands appear

test script
  -> TEST_RUNNER class
  -> dependency on toolchain/binaries
  -> no production identity by default

maintenance script
  -> MAINTENANCE_JOB class
  -> host/service mutation review
  -> elevated privilege review when sudo/root/systemctl/chown appear
```

### Unsupported or review-required script features

These must be preserved as findings and should normally force `needs_review` or `unsafe_refused`:

- `eval`, dynamic `source`, backticks or command substitution that affects commands;
- generated scripts piped into shell, such as `curl ... | sh`;
- unbounded loops, background daemons, uncontrolled `xargs -P`, or recursive self-invocation;
- destructive filesystem operations such as `rm -rf /`, broad `chmod -R 777`, broad `chown -R`;
- privilege escalation through `sudo`, `su`, `doas`, `setcap`, `setuid` changes;
- public firewall/gateway changes;
- wildcard IAM/admin grants or cloud-policy mutation;
- secret printing, `.env` dumping, or credential export to logs.

The adapter should report what it can prove, not invent certainty. Dynamic or ambiguous behaviour is a reason to stage a review gate, not a reason to run the script.

## DGX / GPU cloud workflow policy hook

Adapters must surface DGX/GPU evidence as policy material. When an imported plan mentions DGX, `nvidia.com/gpu`, or GPU accelerator placement, the normalised plan must include a `DGX_CLOUD_WORKFLOW_POLICY_REVIEW` approval gate. When cloud provider markers and workflow/pipeline/DAG markers appear together, the plan must also include `CLOUD_WORKFLOW_POLICY_REVIEW`.

This is a no-live, no-secret, no-submit hook. It exists so cloud and workflow policy can review placement, identity, data movement, cost and gateway exposure before any later apply path.
