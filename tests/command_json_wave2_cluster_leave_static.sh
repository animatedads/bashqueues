#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() { echo "command_json_wave2_cluster_leave_static: $*" >&2; exit 1; }

grep -q 'queuebash.cluster.leave_plan.v1' queuebash.sh || fail "cluster leave JSON schema missing"
grep -q '_queue_cluster_leave_contract' queuebash.sh || fail "cluster leave contract helper missing"
grep -q 'cluster-node-leave' queuebash.sh || fail "cluster-node-leave policy requirement missing"
grep -q 'membership_change_applied":false' queuebash.sh || fail "leave contract must not apply membership change"
grep -q 'token_file_read":false' queuebash.sh || fail "leave contract must not read token files"
grep -q 'secret_value_included":false' queuebash.sh || fail "leave contract must not include secret values"
grep -q 'writes_performed":false' queuebash.sh || fail "leave contract must not write files"
grep -q 'network_touched":false' queuebash.sh || fail "leave contract must not touch network"

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
# shellcheck source=/dev/null
source ./queuebash.sh

json="$(queue cluster leave --node node-z --provider file-dev --reason retirement --dryrun --json)"
printf '%s\n' "$json" | python3 -m json.tool >/dev/null
printf '%s\n' "$json" | grep -q '"schema":"queuebash.cluster.leave_plan.v1"' || fail "schema did not parse as cluster leave plan"
printf '%s\n' "$json" | grep -q '"node_id":"node-z"' || fail "node id missing from JSON"
printf '%s\n' "$json" | grep -q '"provider":"file-dev"' || fail "provider missing from JSON"
printf '%s\n' "$json" | grep -q '"reason":"retirement"' || fail "reason missing from JSON"
printf '%s\n' "$json" | grep -q '"membership_change_applied":false' || fail "membership change must not be applied"
printf '%s\n' "$json" | grep -q '"secret_value_included":false' || fail "secret value posture missing"
printf '%s\n' "$json" | grep -q '"network_touched":false' || fail "network posture missing"

rm -rf "$QUEUEBASH_ROOT"
