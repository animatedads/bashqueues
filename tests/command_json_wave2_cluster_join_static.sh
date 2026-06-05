#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "FAIL: $*" >&2; exit 1; }

grep -q 'queuebash.cluster.join_plan.v1' queuebash.sh || fail 'missing cluster join JSON schema'
grep -q '_queue_cluster_join_contract' queuebash.sh || fail 'missing cluster join contract helper'
grep -q 'token_file_read":false' queuebash.sh || fail 'join contract must not read token files'
grep -q 'secret_value_included":false' queuebash.sh || fail 'join contract must not include secrets'
grep -q 'writes_performed":false' queuebash.sh || fail 'join contract must not write files'
grep -q 'network_touched":false' queuebash.sh || fail 'join contract must not touch network'
grep -q 'fail-closed-for-cluster-mutations' queuebash.sh || fail 'join contract must preserve fail-closed mutation posture'

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="${QUEUEBASH_ROOT:-$(mktemp -d)}"
source ./queuebash.sh
json="$(queue cluster join --node node-c --role worker --provider file-dev --token-file /tmp/not-read.token --dryrun --json)"
printf '%s
' "$json" | python3 -m json.tool >/dev/null || fail 'cluster join JSON did not parse'
printf '%s
' "$json" | grep -q '"schema": *"queuebash.cluster.join_plan.v1"' || fail 'unexpected schema'
printf '%s
' "$json" | grep -q '"node_id": *"node-c"' || fail 'node missing'
printf '%s
' "$json" | grep -q '"role": *"worker"' || fail 'role missing'
printf '%s
' "$json" | grep -q '"token_file_read": *false' || fail 'token file read must be false'
printf '%s
' "$json" | grep -q '"secret_value_included": *false' || fail 'secret value flag must be false'
printf '%s
' "$json" | grep -q '"writes_performed": *false' || fail 'writes flag must be false'
printf '%s
' "$json" | grep -q '"network_touched": *false' || fail 'network flag must be false'
