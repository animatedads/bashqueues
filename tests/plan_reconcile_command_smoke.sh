#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
export QUEUEBASH_PLAN_HELPER="$PWD/bin/queue-plan-ingest.py"
trap 'rm -rf "$QUEUEBASH_ROOT"' EXIT
source ./queuebash.sh
out="$(queue plan reconcile fixtures/plan/reconcile --json)"
printf '%s\n' "$out" | grep -q '"schema":"queue.plan.reconcile.v1"'
printf '%s\n' "$out" | grep -q '"queue plan reconcile consumes supplied files only"'
