#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
export QUEUEBASH_PLAN_HELPER="$PWD/bin/queue-plan-ingest.py"
export QUEUEBASH_BUNDLED_INSTALL_MODE=never
trap 'rm -rf "$QUEUEBASH_ROOT"' EXIT
source ./queuebash.sh
out="$(queue plan handoff fixtures/plan/reconcile --json)"
printf '%s\n' "$out" | grep -q '"schema":"queue.plan.handoff.v1"'
printf '%s\n' "$out" | grep -q '"safe_to_apply":false'
printf '%s\n' "$out" | grep -q '"no parallel cron scheduler"'
