#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="${TMPDIR:-/tmp}/queuebash-cloud-broker-smoke-$$"
rm -rf "$QUEUEBASH_ROOT"
mkdir -p "$QUEUEBASH_ROOT"
trap 'rm -rf "$QUEUEBASH_ROOT"' EXIT

source ./queuebash.sh

queue cloud providers --json | python3 -c 'import json,sys; obj=json.load(sys.stdin); assert obj.get("schema") == "queuebash.cloud_signals.platforms.v1"'
queue cloud provision templates --json | python3 -c 'import json,sys; obj=json.load(sys.stdin); assert obj.get("schema") == "queuebash.cloud_provision.templates.v1"'
queue cloud infra list --json | python3 -c 'import json,sys; obj=json.load(sys.stdin); assert obj.get("schema") == "queuebash.cloud_infra.list.v1"'
queue cloud broker explain --capability vm --profile gdpr-compute --provider aws --region eu-west-2 --service compute --estimated-hourly-usd 0.50 --json \
  | python3 -c 'import json,sys; obj=json.load(sys.stdin); assert obj.get("schema") == "queuebash.cloud_broker.explain.v1"; assert obj.get("non_mutating") is True; assert obj.get("live_api_calls") is False; assert obj.get("dispatch_binding") is False; refs=obj.get("policy_references", []); assert refs and any(r.get("type")=="regulatory" for r in refs) and any(r.get("type")=="corporate" for r in refs)'
