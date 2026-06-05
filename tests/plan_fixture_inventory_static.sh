#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
required=(
  fixtures/plan/native/basic-plan.yaml
  fixtures/plan/kubernetes/job.yaml
  fixtures/plan/kubernetes/cronjob.yaml
  fixtures/plan/kubernetes/networkpolicy.yaml
  fixtures/plan/kubernetes/gateway.yaml
  fixtures/plan/aws-batch/job-definition.json
  fixtures/plan/aws-batch/job-queue.yaml
  fixtures/plan/aws-batch/compute-environment.yaml
  fixtures/plan/azure-batch/pool-job-task.json
  fixtures/plan/gcp-batch/job.yaml
  fixtures/plan/oci/data-science-job.json
  fixtures/plan/oci/data-flow-run.json
  fixtures/plan/ibm-code-engine/job.yaml
  fixtures/plan/slurm/basic.sbatch
  fixtures/plan/slurm/array.sbatch
  fixtures/plan/pbs/basic.pbs
  fixtures/plan/torque/basic.qsub
  fixtures/plan/sge/basic.sge
  fixtures/plan/lsf/basic.bsub
  fixtures/plan/htcondor/basic.submit
  fixtures/plan/flux/jobspec.yaml
  fixtures/plan/nomad/basic.nomad
  fixtures/plan/argo/workflow.yaml
  fixtures/plan/tekton/pipeline.yaml
  fixtures/plan/gitlab/.gitlab-ci.yml
  fixtures/plan/github-actions/workflow.yml
  fixtures/plan/systemd/example.service
  fixtures/plan/systemd/example.timer
  fixtures/plan/cron/crontab
  fixtures/plan/script/backup-and-upload.sh
  fixtures/plan/script/migration-with-review.sh
  fixtures/plan/script/unsafe-curl-pipe.sh
  fixtures/plan/script/expected-script-behaviour-control-plan.json
)
for rel in "${required[@]}"; do
  [[ -s "$ROOT/$rel" ]] || { echo "missing or empty fixture: $rel" >&2; exit 1; }
done
# Ensure legacy HPC forms are present, not only cloud YAML.
for legacy in torque sge lsf; do
  find "$ROOT/fixtures/plan/$legacy" -type f | grep -q . || { echo "missing legacy fixture family: $legacy" >&2; exit 1; }
done

# Script-behaviour coverage is distinct from cron/systemd and must remain present.
find "$ROOT/fixtures/plan/script" -type f | grep -q . || { echo "missing script-behaviour fixture family" >&2; exit 1; }
