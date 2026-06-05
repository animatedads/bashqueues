#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="bin/queue-plan-ingest.py"
for token in \
  azure-logic-apps aws-step-functions gcp-cloud-run-jobs oci-work-request \
  ibm-watsonx-ai alibaba-ehpc huawei-batch tencent-batch \
  windows-task-scheduler local-cron-status local-systemd-timer-status \
  celery-runtime rq-runtime apscheduler-runtime slurm-runtime htcondor-runtime \
  kubernetes-runtime volcano-runtime airflow-runtime prefect-runtime dagster-runtime; do
  grep -Fq "\"$token\"" "$helper" || { echo "missing runtime adapter token: $token" >&2; exit 1; }
done
grep -Fq 'queue plan status PATH [--json]' queuebash.sh
grep -Fq 'queue plan status PATH [--json]' resources.d/display/lang_eng/plan-help.txt
grep -Fq 'Runtime/status sources are exported-fact inputs only' bin/queue-plan-ingest.py
grep -Fq 'Windows Task Scheduler' docs/PLAN_RUNTIME_STATUS_COVERAGE.md
grep -Fq 'Celery' docs/PLAN_RUNTIME_STATUS_COVERAGE.md
