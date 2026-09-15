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
' '0.18.136' > "$QUEUEBASH_ROOT/.queuebash_bundled_install_version"
source ./queuebash.sh

queue cluster init --name vote-evaluate-smoke --profile enterprise-default --materialize --json >/dev/null
proposal_json="$(queue cluster vote propose --operation policy_change --reason smoke --materialize --json)"
proposal_id="$(printf '%s
' "$proposal_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["proposal_id"])')"
queue cluster vote cast --proposal-id "$proposal_id" --decision approve --reason smoke --materialize --json >/dev/null
json="$(queue cluster vote evaluate --proposal-id "$proposal_id" --json)"
printf '%s
' "$json" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["schema"]=="queuebash.cluster.vote_evaluation.v1"; assert o["status"]=="evaluated"; assert o["proposal_id"]; assert o["operation"]=="policy_change"; assert o["local_ballots"]==1; assert o["approve"]==1; assert o["reject"]==0; assert o["decision"]=="blocked_provider_required"; assert o["eligible_voters_source"]=="provider-required"; assert o["writes_performed"] is False; assert o["network_touched"] is False; assert o["quorum_granted"] is False; assert o["cluster_mutation_unlocked"] is False'

missing_json="$(queue cluster vote evaluate --proposal-id missing-proposal --json 2>/dev/null || true)"
printf '%s
' "$missing_json" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["schema"]=="queuebash.cluster.vote_evaluation.v1"; assert o["status"]=="missing"; assert o["decision"]=="blocked_missing_proposal"; assert o["writes_performed"] is False; assert o["network_touched"] is False'

echo "PASS cluster_vote_evaluate_smoke"
