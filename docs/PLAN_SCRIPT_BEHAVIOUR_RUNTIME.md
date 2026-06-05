# Queue plan script-behaviour runtime adapter

Bob24 promotes the accepted script-behaviour design into the inert `queue plan` helper.

The adapter recognizes shell-like operational scripts as source plans:

```text
.sh
.bash
shell shebang scripts
```

It does not execute the script. It does not source it, expand variables from the live environment, run command substitution, fetch secrets, contact cloud APIs, run package managers, submit jobs, or apply infrastructure. It only reads text and emits conservative plan facts.

Runtime schema emitted inside detected objects:

```text
queue.plan.script_behaviour.v1
```

## Class hints

The adapter may emit these candidate classes:

```text
BACKUP_JOB
DATABASE_MIGRATION
DEPLOYMENT_ORCHESTRATION
TEST_RUNNER
MAINTENANCE_JOB
SCRIPT_BEHAVIOUR
```

These are hints, not proof of safety. Script-derived plans require review before execution.

## Evidence mapping

```text
pg_dump, mysqldump, mongodump, redis-cli --rdb
  -> BACKUP_JOB, database asset, database credential reference

psql, mysql, migrate, liquibase, flyway, alembic
  -> DATABASE_MIGRATION, database asset

aws s3 cp, gcloud storage cp, az storage, oci object-storage style usage
  -> BACKUP_JOB, object_storage asset, cloud identity requirement

aws, az, gcloud, oci, ibmcloud
  -> cloud_provider asset and cloud_identity restriction candidate

kubectl apply, helm upgrade, terraform apply, tofu apply, pulumi up
  -> DEPLOYMENT_ORCHESTRATION and needs_review control-plane mutation

pytest, bats, npm test, go test, make test
  -> TEST_RUNNER

systemctl, service, logrotate, chmod, chown, vacuumdb
  -> MAINTENANCE_JOB and review where host mutation or privilege is visible

curl, wget, ssh, scp, rsync
  -> network_egress asset candidate

mkdir -p, install -d
  -> filesystem_writable_path asset candidate
```

## Review and refusal

All script-derived plans include a `script_static_review_required` review marker.

Unsafe refusal is emitted for clearly dangerous patterns such as:

```text
curl/wget piped to sh/bash
rm -rf /
chmod -R 777
```

Other high-risk evidence such as `sudo`, `systemctl restart`, or control-plane mutation commands is marked `needs_review`.

## Boundaries preserved

```text
no live cloud calls
no secret reads
no job submission
no source execution
no lifecycle mutation
no parallel cron scheduler
```

The existing bashqueues cron support remains authoritative for cron-like execution.
