#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/root"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
mkdir -p "$QUEUEBASH_ROOT/classes"
printf '%s
' 'CLASS_ALLOW_PARALLEL=1' 'CLASS_MAX_CONCURRENT=0' > "$QUEUEBASH_ROOT/classes/DEFAULT.env"
printf '%s
' '0.18.119' > "$QUEUEBASH_ROOT/.queuebash_bundled_install_version"
source ./queuebash.sh

queue cluster init --name lease-smoke --profile enterprise-default --materialize --json >/dev/null
json="$(queue cluster elect lease --materialize --ttl-seconds 45 --json)"
printf '%s
' "$json" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["schema"]=="queuebash.cluster.local_lease.v1"; assert o["status"]=="held-local"; assert o["leader"]=="local"; assert o["lease_epoch"]>=1; assert o["lease_ttl_seconds"]==45; assert o["writes_performed"] is True; assert o["network_touched"] is False; assert o["provider"]=="file-dev"; assert o["scope"]=="local-only"'

test -f "$QUEUEBASH_ROOT/cluster/lease.env" || { echo "FAIL cluster_lease_smoke: lease.env missing" >&2; exit 1; }
grep -q '^QUEUEBASH_CLUSTER_LEASE_LEADER=local$' "$QUEUEBASH_ROOT/cluster/lease.env" || { echo "FAIL cluster_lease_smoke: lease leader missing" >&2; exit 1; }
grep -q '^QUEUEBASH_CLUSTER_LEASE_PROVIDER=file-dev$' "$QUEUEBASH_ROOT/cluster/lease.env" || { echo "FAIL cluster_lease_smoke: lease provider missing" >&2; exit 1; }
grep -q 'cluster_local_lease_materialized' "$QUEUEBASH_ROOT/cluster/cluster_events.jsonl" || { echo "FAIL cluster_lease_smoke: audit event missing" >&2; exit 1; }

status_json="$(queue cluster elect status --json)"
printf '%s
' "$status_json" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["schema"]=="queuebash.cluster.election_status.v1"; assert o["lease_state"]=="held-local"; assert o["lease_epoch"]>=1; assert o["network_touched"] is False'

echo "PASS cluster_lease_smoke"
