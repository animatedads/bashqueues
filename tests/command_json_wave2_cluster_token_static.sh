#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "command_json_wave2_cluster_token_static: $*" >&2; exit 1; }

grep -q 'queuebash.cluster.node_token_plan.v1' queuebash.sh || fail 'missing cluster node token JSON schema'
grep -q 'token_materialised":false' queuebash.sh || fail 'missing token_materialised=false guard'
grep -q 'secret_value_included":false' queuebash.sh || fail 'missing secret_value_included=false guard'
grep -q 'network_touched":false' queuebash.sh || fail 'missing network_touched=false guard'
grep -q 'writes_performed":false' queuebash.sh || fail 'missing writes_performed=false guard'

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="${QUEUEBASH_ROOT:-$(mktemp -d)}"
# shellcheck source=/dev/null
source ./queuebash.sh

json="$(queue cluster node token create --node node-a --role worker --json)"
printf '%s\n' "$json" | python3 -m json.tool >/dev/null || fail 'token plan JSON did not parse'
printf '%s\n' "$json" | grep -q '"schema": *"queuebash.cluster.node_token_plan.v1"' || fail 'unexpected schema'
printf '%s\n' "$json" | grep -q '"token_materialised": *false' || fail 'token materialisation guard missing in output'
printf '%s\n' "$json" | grep -q '"secret_value_included": *false' || fail 'secret guard missing in output'
printf '%s\n' "$json" | grep -q '"network_touched": *false' || fail 'network guard missing in output'
