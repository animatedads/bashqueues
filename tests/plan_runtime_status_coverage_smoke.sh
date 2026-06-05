#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="bin/queue-plan-ingest.py"
out="${TMPDIR:-/tmp}/queue_plan_runtime_status.json"
python3 "$helper" status fixtures/plan/runtime --json > "$out"
python3 - "$out" <<'PY'
import json, sys
obj=json.load(open(sys.argv[1]))
assert obj["schema"] == "queue.plan.status.v1"
adapters={s["adapter"] for s in obj.get("status_sources", [])}
required={
  "azure-logic-apps", "aws-step-functions", "gcp-cloud-run-jobs", "oci-work-request",
  "ibm-watsonx-ai", "alibaba-ehpc", "huawei-batch", "tencent-batch",
  "windows-task-scheduler", "local-cron-status", "local-systemd-timer-status",
  "celery-runtime", "rq-runtime", "apscheduler-runtime", "slurm-runtime", "htcondor-runtime",
  "kubernetes-runtime", "volcano-runtime", "airflow-runtime", "prefect-runtime", "dagster-runtime",
}
missing=required-adapters
assert not missing, f"missing adapters: {sorted(missing)}"
assert obj["safe_to_apply"] is False
assert "no SDK/API/CLI/WinRM/SMB/RPC/REST" in obj["execution_boundary"]
PY
