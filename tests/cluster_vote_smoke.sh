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

queue cluster init --name vote-smoke --profile enterprise-default --materialize --json >/dev/null
plan="$(queue cluster vote propose --operation policy_change --reason smoke --json)"
printf '%s
' "$plan" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["schema"]=="queuebash.cluster.vote_proposal.v1"; assert o["status"]=="contract_only"; assert o["writes_performed"] is False; assert o["network_touched"] is False; assert o["pending_votes"]==0'
test ! -d "$QUEUEBASH_ROOT/cluster/votes.d" || { echo "FAIL cluster_vote_smoke: dry-run created votes dir" >&2; exit 1; }

json="$(queue cluster vote propose --operation policy_change --reason smoke --materialize --json)"
printf '%s
' "$json" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["schema"]=="queuebash.cluster.vote_proposal.v1"; assert o["status"]=="pending"; assert o["operation"]=="policy_change"; assert o["reason"]=="smoke"; assert o["proposal_id"].startswith("vote-"); assert o["pending_votes"]==1; assert o["writes_performed"] is True; assert o["network_touched"] is False; assert o["provider"]=="file-dev"; assert o["scope"]=="local-only"'

test -d "$QUEUEBASH_ROOT/cluster/votes.d" || { echo "FAIL cluster_vote_smoke: votes dir missing" >&2; exit 1; }
ls "$QUEUEBASH_ROOT/cluster/votes.d"/*.env >/dev/null 2>&1 || { echo "FAIL cluster_vote_smoke: vote record missing" >&2; exit 1; }
grep -q 'cluster_vote_proposal_materialized' "$QUEUEBASH_ROOT/cluster/cluster_events.jsonl" || { echo "FAIL cluster_vote_smoke: audit event missing" >&2; exit 1; }

status="$(queue cluster vote status --json)"
printf '%s
' "$status" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["schema"]=="queuebash.cluster.vote_status.v1"; assert o["pending_votes"]==1; assert o["latest_proposal_id"].startswith("vote-"); assert o["network_touched"] is False'

if queue cluster vote propose --operation 'bad/name' --reason smoke --materialize >/dev/null 2>&1; then
  echo 'FAIL cluster_vote_smoke: unsafe vote operation accepted' >&2
  exit 1
fi

echo "PASS cluster_vote_smoke"
