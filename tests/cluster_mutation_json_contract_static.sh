#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "FAIL cluster_mutation_json_contract_static: $*" >&2; exit 1; }

grep -q 'queuebash.cluster.mutation_blocked.v1' queuebash.sh || fail 'mutation blocked schema missing'
grep -q '_queue_cluster_mutation_blocked_json' queuebash.sh || fail 'mutation blocked JSON helper missing'
grep -q -- '--dryrun|--dry-run' queuebash.sh || fail 'cluster init dry-run aliases missing'
grep -q '"dry_run":%s' queuebash.sh || fail 'cluster init dry_run JSON field missing'
grep -q 'default_decision.*fail-closed-for-cluster-mutations' queuebash.sh || fail 'fail-closed default decision missing'
grep -q 'queue cluster join \[--json\]' contracts/CLUSTER_COMMAND_CONTRACT.md || fail 'join JSON contract missing from docs'
grep -q 'queue cluster pause \[--json\]' contracts/CLUSTER_COMMAND_CONTRACT.md || fail 'pause JSON contract missing from docs'
grep -q 'queuebash.cluster.join_plan.v1' contracts/CLUSTER_COMMAND_CONTRACT.md || fail 'join plan schema missing from command contract'
grep -q 'queuebash.cluster.mutation_blocked.v1' contracts/CLUSTER_COMMAND_CONTRACT.md || fail 'mutation schema missing from command contract'

echo "PASS cluster_mutation_json_contract_static"
