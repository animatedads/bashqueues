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

queue cluster init --name vote-apply-smoke --profile enterprise-default --materialize --json >/dev/null
proposal_json="$(queue cluster vote propose --operation policy_change --reason smoke --materialize --json)"
proposal_id="$(printf '%s
' "$proposal_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["proposal_id"])')"
queue cluster vote cast --proposal-id "$proposal_id" --decision approve --reason smoke --materialize --json >/dev/null
json="$(queue cluster vote apply --proposal-id "$proposal_id" --json 2>/dev/null || true)"
printf '%s
' "$json" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["schema"]=="queuebash.cluster.vote_apply_preflight.v1"; assert o["status"]=="blocked"; assert o["proposal_id"]; assert o["operation"]=="policy_change"; assert o["local_ballots"]==1; assert o["approve"]==1; assert o["decision"]=="blocked_provider_required"; assert o["mutation_applied"] is False; assert o["writes_performed"] is False; assert o["network_touched"] is False; assert o["quorum_granted"] is False; assert o["cluster_mutation_unlocked"] is False'

if queue cluster vote apply --proposal-id "$proposal_id" >/dev/null 2>&1; then
  echo 'FAIL cluster_vote_apply_smoke: file-dev apply unexpectedly succeeded' >&2
  exit 1
fi

missing_json="$(queue cluster vote apply --proposal-id missing-proposal --json 2>/dev/null || true)"
printf '%s
' "$missing_json" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["schema"]=="queuebash.cluster.vote_apply_preflight.v1"; assert o["status"]=="blocked"; assert o["decision"]=="blocked_missing_proposal"; assert o["mutation_applied"] is False; assert o["writes_performed"] is False; assert o["network_touched"] is False'

echo "PASS cluster_vote_apply_smoke"
