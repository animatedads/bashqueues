# Queue plan script behaviour model

Bob24 script-to-plan coverage treats an ordinary operational script as a possible source plan. The objective is not to run the script. The objective is to statically normalize common, deterministic script behaviour into `queue.control_plan.v1` so an administrator can understand the bashqueues classes, restrictions, assets and dependencies implied by a script before deciding whether it should run.

## Adapter name

```text
script-behaviour
```

Initial input scope:

```text
.sh
.bash
POSIX/Bash files with a shell shebang
executable text scripts identified by conservative shell syntax
```

Future input scope may include PowerShell, Python task scripts and Makefiles, but only under the same static/no-execution rules.

## Non-execution boundary

The adapter must not:

- execute the script;
- `source` the script;
- run command substitution;
- expand variables using the live environment;
- call package managers, cloud CLIs, Kubernetes tools or databases;
- fetch secrets;
- follow remote URLs;
- run embedded Python/Perl/Ruby/Node fragments;
- infer success merely because a command is present.

It may read the file as text, parse conservative syntax, classify known command tokens, and preserve unknown or dynamic lines as evidence.

## Behaviour normalization

The adapter should emit observations into the same plan object families used by every other `queue plan` adapter:

| Script evidence | Plan inference |
| --- | --- |
| `set -euo pipefail`, `trap cleanup EXIT` | safety/failure-policy evidence |
| `command -v psql`, `test -x /usr/bin/rsync` | tool dependencies |
| `mkdir -p /path`, `install -d /path` | filesystem asset and writable path candidate |
| `cp`, `mv`, `rsync`, `tar`, `find` | filesystem read/write restrictions |
| `curl`, `wget`, `ssh`, `scp`, `rsync host:` | network egress candidate and remote endpoint dependency |
| `psql`, `mysql`, `sqlite3`, `mongosh`, `redis-cli` | database asset, credential reference and database class candidate |
| `aws`, `az`, `gcloud`, `oci`, `ibmcloud` | cloud provider asset and identity restriction candidate |
| `kubectl`, `helm`, `terraform`, `tofu`, `pulumi` | control-plane mutation review gate |
| `docker`, `podman`, `buildah`, `nerdctl` | container runner/build class implication |
| `systemctl`, `service`, `crontab` | host service/schedule mutation review gate |
| `sudo`, `su`, `doas`, `setcap`, broad `chown`/`chmod` | privilege escalation review/refusal evidence |
| bounded `for x in a b c` | fanout candidate |
| command order | dependency edge candidate |

## Class inference hints

The script adapter should use conservative hints, never absolute claims:

```text
backup-like
  evidence: pg_dump/mysqldump/tar/rsync/aws s3 cp/gcloud storage cp
  candidate class: BACKUP_JOB
  likely assets: filesystem, database, object storage, network egress

migration-like
  evidence: psql/mysql migrate/liquibase/flyway/alembic
  candidate class: DATABASE_MIGRATION
  likely restrictions: max_concurrent=1, manual approval, database credential reference

deployment-like
  evidence: kubectl apply, helm upgrade, terraform apply, systemctl restart
  candidate class: DEPLOYMENT_ORCHESTRATION or SERVICE_ROLLOUT
  likely restrictions: provider/control-plane identity, review before apply

test-like
  evidence: pytest, bats, npm test, go test, make test
  candidate class: TEST_RUNNER
  likely restrictions: no production identity, toolchain dependency

maintenance-like
  evidence: logrotate, vacuum, cleanup, systemctl, chmod/chown
  candidate class: MAINTENANCE_JOB
  likely restrictions: host mutation and privilege review
```

## Risk handling

Script-derived plans are lower confidence than declarative plans. The adapter must mark `needs_review` for dynamic or ambiguous behaviour and `unsafe_refused` for clearly dangerous patterns.

Review or refusal triggers include:

```text
eval
source of non-static path
curl/wget piped to sh/bash
backticks or command substitution that constructs a command
rm -rf / or broad destructive deletion
chmod -R 777
broad chown -R
sudo/su/doas privilege escalation
setcap or setuid mutation
iptables/firewall/public-gateway mutation
cloud IAM wildcard/admin policy mutation
secret printing or env dumping
unbounded loops or background daemonization
```

## Example normalized intent

A backup script that runs `pg_dump`, writes to `/var/backups/app`, and uploads to `s3://example-backups` should explain as:

```text
candidate class: BACKUP_JOB
assets: database, filesystem path, object storage endpoint
restrictions: no inbound network, egress to database/object storage, writable backup path only
secrets: database/object-storage references only
approval gates: required if production database or privileged filesystem paths are detected
safe_to_apply: false until reviewed
```

## Acceptance posture

The first Bob24 implementation should be documentation, fixtures and static contract tests only. Runtime command support may follow after the adapter contract is accepted.
