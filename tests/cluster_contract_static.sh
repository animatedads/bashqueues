#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "FAIL cluster_contract_static: $*" >&2; exit 1; }

grep -q '_queue_cluster_command' queuebash.sh || fail 'cluster command function missing'
grep -q 'queuebash.cluster.status.v1' queuebash.sh || fail 'cluster status JSON schema missing'
grep -q 'network_touched":false' queuebash.sh || fail 'standalone no-network marker missing'
grep -q 'writes_performed":false' queuebash.sh || fail 'standalone no-write marker missing'
grep -q 'cluster)' queuebash.sh || fail 'queue dispatch for cluster missing'

grep -q '_queue_cluster_materialize_file_dev' queuebash.sh || fail 'cluster materialize helper missing'
grep -q 'queuebash.cluster.init_result.v1' queuebash.sh || fail 'cluster materialize JSON schema missing'
grep -q -- '--materialize' contracts/CLUSTER_COMMAND_CONTRACT.md || fail 'materialize command contract missing'
grep -q '_queue_cluster_materialize_local_lease' queuebash.sh || fail 'cluster local lease helper missing'
grep -q 'queuebash.cluster.local_lease.v1' queuebash.sh || fail 'cluster local lease JSON schema missing'
grep -q 'queue cluster elect lease' contracts/CLUSTER_COMMAND_CONTRACT.md || fail 'cluster elect lease command contract missing'
grep -q '_queue_cluster_vote_propose' queuebash.sh || fail 'cluster vote propose helper missing'
grep -q 'queuebash.cluster.vote_proposal.v1' queuebash.sh || fail 'cluster vote proposal JSON schema missing'
grep -q 'queue cluster vote propose' contracts/CLUSTER_COMMAND_CONTRACT.md || fail 'cluster vote propose command contract missing'
grep -q '_queue_cluster_vote_cast' queuebash.sh || fail 'cluster vote cast helper missing'
grep -q 'queuebash.cluster.vote_cast.v1' queuebash.sh || fail 'cluster vote cast JSON schema missing'
grep -q 'queue cluster vote cast' contracts/CLUSTER_COMMAND_CONTRACT.md || fail 'cluster vote cast command contract missing'

grep -q 'Bob25 cluster operations design' docs/CLUSTER_OPERATIONS_DESIGN.md || fail 'design doc missing'
grep -q 'queue cluster status' contracts/CLUSTER_COMMAND_CONTRACT.md || fail 'command contract missing'
grep -q 'Cluster providers are coordination backends' contracts/CLUSTER_PROVIDER_CONTRACT.md || fail 'provider contract missing'
test -f policies.d/cluster/cluster.env.example || fail 'cluster policy example missing'
test -f policies.d/cluster/egress.env.example || fail 'egress policy example missing'
test -f policies.d/cluster/voting.env.example || fail 'voting policy example missing'

echo "PASS cluster_contract_static"
