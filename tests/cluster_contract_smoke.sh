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

json="$(queue cluster status --json)"
printf '%s\n' "$json" | python3 -c "import json,sys; obj=json.load(sys.stdin); assert obj['schema']=='queuebash.cluster.status.v1'; assert obj['mode']=='standalone'; assert obj['cluster_enabled'] is False; assert obj['network_touched'] is False; assert obj['writes_performed'] is False; assert obj['provider']=='standalone'"

queue cluster policy paths --json >/dev/null
queue cluster elect status --json >/dev/null
queue cluster elect lease --json >/dev/null
queue cluster vote status --json >/dev/null
queue cluster vote propose --operation policy_change --reason smoke --json >/dev/null
queue cluster node list --json >/dev/null
queue cluster explain --json >/dev/null
queue cluster init --name smoke --json >/dev/null

echo "PASS cluster_contract_smoke"
