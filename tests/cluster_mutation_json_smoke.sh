#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/root"
mkdir -p "$QUEUEBASH_ROOT/classes"
printf '%s
' 'CLASS_ALLOW_PARALLEL=1' 'CLASS_MAX_CONCURRENT=0' > "$QUEUEBASH_ROOT/classes/DEFAULT.env"
printf '%s
' '0.18.123' > "$QUEUEBASH_ROOT/.queuebash_bundled_install_version"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh

init_json="$(queue cluster init --name smoke --profile enterprise-default --dryrun --json)"
printf '%s
' "$init_json" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["schema"]=="queuebash.cluster.init_plan.v1"; assert o["dry_run"] is True; assert o["writes_performed"] is False; assert o["network_touched"] is False'

set +e
join_json="$(queue cluster join --json 2>/tmp/cluster_join_json_smoke.err)"
join_rc=$?
set -e
[[ "$join_rc" -ne 0 ]] || { echo "FAIL cluster_mutation_json_smoke: join unexpectedly succeeded" >&2; exit 1; }
printf '%s
' "$join_json" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["schema"]=="queuebash.cluster.mutation_blocked.v1"; assert o["status"]=="blocked"; assert o["operation"]=="join"; assert o["writes_performed"] is False; assert o["network_touched"] is False; assert o["default_decision"]=="fail-closed-for-cluster-mutations"'

set +e
out="$(queue cluster pause --json 2>/tmp/cluster_mutation_json_smoke.err)"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || { echo "FAIL cluster_mutation_json_smoke: pause unexpectedly succeeded" >&2; exit 1; }
printf '%s
' "$out" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["schema"]=="queuebash.cluster.mutation_blocked.v1"; assert o["status"]=="blocked"; assert o["network_touched"] is False; assert o["writes_performed"] is False; assert o["default_decision"]=="fail-closed-for-cluster-mutations"'

echo "PASS cluster_mutation_json_smoke"
