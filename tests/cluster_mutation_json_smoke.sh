#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/root"
mkdir -p "$QUEUEBASH_ROOT/classes"
printf '%s\n' 'CLASS_ALLOW_PARALLEL=1' 'CLASS_MAX_CONCURRENT=0' > "$QUEUEBASH_ROOT/classes/DEFAULT.env"
printf '%s\n' '0.18.115' > "$QUEUEBASH_ROOT/.queuebash_bundled_install_version"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh

init_json="$(queue cluster init --name smoke --profile enterprise-default --dryrun --json)"
printf '%s\n' "$init_json" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["schema"]=="queuebash.cluster.init_plan.v1"; assert o["dry_run"] is True; assert o["writes_performed"] is False; assert o["network_touched"] is False'

for cmd in \
  "queue cluster join --json" \
  "queue cluster pause --json"; do
    set +e
    out="$(eval "$cmd" 2>/tmp/cluster_mutation_json_smoke.err)"
    rc=$?
    set -e
    [[ "$rc" -ne 0 ]] || { echo "FAIL cluster_mutation_json_smoke: mutation unexpectedly succeeded: $cmd" >&2; exit 1; }
    printf '%s\n' "$out" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["schema"]=="queuebash.cluster.mutation_blocked.v1"; assert o["status"]=="blocked"; assert o["network_touched"] is False; assert o["writes_performed"] is False; assert o["default_decision"]=="fail-closed-for-cluster-mutations"'
done

echo "PASS cluster_mutation_json_smoke"
