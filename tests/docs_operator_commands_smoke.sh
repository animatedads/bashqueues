#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
export QUEUEBASH_POLICY_SYSTEM_ROOT="$(mktemp -d)"
export QUEUEBASH_CRON_SPOOL_DIR="$(mktemp -d)"
export QUEUEBASH_CRON_SYSTEM_DIR="$(mktemp -d)"
export QUEUEBASH_CRON_STATE_DIR="$(mktemp -d)"
trap 'rm -rf "$QUEUEBASH_ROOT" "$QUEUEBASH_POLICY_SYSTEM_ROOT" "$QUEUEBASH_CRON_SPOOL_DIR" "$QUEUEBASH_CRON_SYSTEM_DIR" "$QUEUEBASH_CRON_STATE_DIR"' EXIT
source ./queuebash.sh

queue version >/tmp/docs-runbook-version.out
queue version --json | python3 -m json.tool >/dev/null
queue policy paths --json | python3 -m json.tool >/dev/null
queue policy status --json | python3 -m json.tool >/dev/null
bash ./install-system.sh --dryrun >/tmp/docs-runbook-install-dryrun.out
bin/queue-policy-wizard --scope system --dryrun --non-interactive --json | python3 -m json.tool >/dev/null
bash tests/policy_namespace_consistency_static.sh >/tmp/docs-runbook-policy-namespace.out
queue enterprise list-profiles --json | python3 -m json.tool >/dev/null
queue enterprise validate-profile hospital-live-readonly-default --json | python3 -m json.tool >/dev/null
queue enterprise validate-profile hospital-live-approved-maintenance-default --json | python3 -m json.tool >/dev/null
queue enterprise verify-maintenance --request examples/enterprise/maintenance-request.example.json --json | python3 -m json.tool >/dev/null
queue health --json | python3 -m json.tool >/dev/null
queue health --deep --json | python3 -m json.tool >/dev/null

echo 'PASS docs_operator_commands_smoke'
