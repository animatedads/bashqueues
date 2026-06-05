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
' '0.18.123' > "$QUEUEBASH_ROOT/.queuebash_bundled_install_version"
source ./queuebash.sh

queue cluster init --name vote-cast-smoke --profile enterprise-default --materialize --json >/dev/null
proposal_json="$(queue cluster vote propose --operation policy_change --reason smoke --materialize --json)"
proposal_id="$(printf '%s
' "$proposal_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["proposal_id"])')"

plan="$(queue cluster vote cast --proposal-id "$proposal_id" --decision approve --reason dryrun --json)"
printf '%s
' "$plan" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["schema"]=="queuebash.cluster.vote_cast.v1"; assert o["status"]=="contract_only"; assert o["writes_performed"] is False; assert o["network_touched"] is False; assert o["quorum_granted"] is False; assert o["cluster_mutation_unlocked"] is False'
test ! -d "$QUEUEBASH_ROOT/cluster/votes.d/$proposal_id.ballots.d" || { echo "FAIL cluster_vote_cast_smoke: dry-run created ballots dir" >&2; exit 1; }

json="$(queue cluster vote cast --proposal-id "$proposal_id" --decision approve --reason smoke --materialize --json)"
printf '%s
' "$json" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["schema"]=="queuebash.cluster.vote_cast.v1"; assert o["status"]=="cast"; assert o["decision"]=="approve"; assert o["local_ballots"]==1; assert o["writes_performed"] is True; assert o["network_touched"] is False; assert o["quorum_granted"] is False; assert o["cluster_mutation_unlocked"] is False; assert o["provider"]=="file-dev"; assert o["scope"]=="local-only"'

test -d "$QUEUEBASH_ROOT/cluster/votes.d/$proposal_id.ballots.d" || { echo "FAIL cluster_vote_cast_smoke: ballots dir missing" >&2; exit 1; }
ls "$QUEUEBASH_ROOT/cluster/votes.d/$proposal_id.ballots.d"/*.env >/dev/null 2>&1 || { echo "FAIL cluster_vote_cast_smoke: ballot record missing" >&2; exit 1; }
grep -q 'cluster_vote_cast_materialized' "$QUEUEBASH_ROOT/cluster/cluster_events.jsonl" || { echo "FAIL cluster_vote_cast_smoke: audit event missing" >&2; exit 1; }

status="$(queue cluster vote status --json)"
printf '%s
' "$status" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["schema"]=="queuebash.cluster.vote_status.v1"; assert o["pending_votes"]==1; assert o["local_ballots"]==1; assert o["network_touched"] is False'

if queue cluster vote cast --proposal-id "$proposal_id" --decision maybe --reason smoke --materialize >/dev/null 2>&1; then
  echo 'FAIL cluster_vote_cast_smoke: invalid decision accepted' >&2
  exit 1
fi
if queue cluster vote cast --proposal-id missing-proposal --decision approve --reason smoke --materialize >/dev/null 2>&1; then
  echo 'FAIL cluster_vote_cast_smoke: missing proposal accepted for materialized cast' >&2
  exit 1
fi

echo "PASS cluster_vote_cast_smoke"
