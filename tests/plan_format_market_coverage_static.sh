#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$ROOT/docs/PLAN_FORMAT_MARKET_COVERAGE.md"
ADAPTER="$ROOT/docs/PLAN_ADAPTER_CONTRACT.md"
CONTROL="$ROOT/docs/PLAN_CONTROL_MODEL.md"
PRIORITY="$ROOT/docs/PLAN_FORMAT_PRIORITY.md"
for f in "$DOC" "$ADAPTER" "$CONTROL" "$PRIORITY"; do
  [[ -f "$f" ]] || { echo "missing $f" >&2; exit 1; }
done
for token in \
  "Native bashqueues" "Kubernetes" "AWS" "Azure" "Google Cloud" "Oracle OCI" "IBM Cloud" \
  "Slurm" "OpenPBS" "Torque" "SGE" "Grid Engine" "LSF" "HTCondor" "Flux" \
  "Nomad" "systemd" "cron" "Argo" "Tekton" "Airflow" "GitHub Actions" "GitLab CI" "Jenkinsfile" \
  "Terraform" "OpenTofu" "Pulumi" "CloudFormation" "ARM" "Bicep" "Script behaviour" "script-behaviour"; do
  grep -q "$token" "$DOC" || { echo "market coverage missing token: $token" >&2; exit 1; }
done
grep -q "Cron is not a normal foreign-plan adapter" "$ADAPTER" || { echo "cron special-case contract missing" >&2; exit 1; }
grep -q "classes" "$CONTROL" || { echo "control model missing classes" >&2; exit 1; }
grep -q "restrictions" "$CONTROL" || { echo "control model missing restrictions" >&2; exit 1; }
grep -q "gateway" "$CONTROL" || { echo "control model missing gateway" >&2; exit 1; }
grep -q "Phase 1" "$PRIORITY" || { echo "priority doc missing phases" >&2; exit 1; }

grep -q "Script-to-plan adapter" "$ADAPTER" || { echo "script-to-plan adapter contract missing" >&2; exit 1; }
grep -q "Script-derived plans" "$CONTROL" || { echo "script-derived control model missing" >&2; exit 1; }
grep -q "common script-behaviour static adapter" "$PRIORITY" || { echo "script-behaviour priority missing" >&2; exit 1; }
