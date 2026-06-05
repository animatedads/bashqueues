#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/root"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
mkdir -p "$QUEUEBASH_ROOT"
echo "0.18.119" > "$QUEUEBASH_ROOT/.queuebash_bundled_install_version"
source ./queuebash.sh

plan="$(queue cluster init --name smoke-a --json)"
printf '%s\n' "$plan" | grep -q '"schema":"queuebash.cluster.init_plan.v1"'
printf '%s\n' "$plan" | grep -q '"writes_performed":false'
printf '%s\n' "$plan" | grep -q '"network_touched":false'
test ! -e "$QUEUEBASH_ROOT/cluster/cluster.env"

result="$(queue cluster init --name smoke-a --profile enterprise-default --materialize --json)"
printf '%s\n' "$result" | grep -q '"schema":"queuebash.cluster.init_result.v1"'
printf '%s\n' "$result" | grep -q '"status":"materialized"'
printf '%s\n' "$result" | grep -q '"writes_performed":true'
printf '%s\n' "$result" | grep -q '"network_touched":false'
printf '%s\n' "$result" | grep -q '"egress_mode":"local-only"'
printf '%s\n' "$result" | grep -q '"legal_scope":"local"'
test -f "$QUEUEBASH_ROOT/cluster/cluster.env"
test -f "$QUEUEBASH_ROOT/cluster/nodes.d/local.env"
test -f "$QUEUEBASH_ROOT/cluster/cluster_events.jsonl"
grep -q '^QUEUEBASH_CLUSTER_ENABLED=1$' "$QUEUEBASH_ROOT/cluster/cluster.env"

status="$(queue cluster status --json)"
printf '%s\n' "$status" | grep -q '"schema":"queuebash.cluster.status.v1"'
printf '%s\n' "$status" | grep -q '"mode":"cluster"'
printf '%s\n' "$status" | grep -q '"cluster_enabled":true'
printf '%s\n' "$status" | grep -q '"provider":"file-dev"'
printf '%s\n' "$status" | grep -q '"network_touched":false'

nodes="$(queue cluster node list --json)"
printf '%s\n' "$nodes" | grep -q '"role":"controller"'
printf '%s\n' "$nodes" | grep -q '"network_touched":false'

if queue cluster init --name 'bad/name' --materialize >/dev/null 2>&1; then
  echo 'FAIL cluster_materialize_smoke: unsafe cluster name accepted' >&2
  exit 1
fi

echo "PASS cluster_materialize_smoke"
