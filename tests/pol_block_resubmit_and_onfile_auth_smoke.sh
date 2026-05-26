#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
# shellcheck source=../queuebash.sh
source ./queuebash.sh
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export QUEUEBASH_ROOT="$TMP/q"
export QUEUEBASH_POLICY_SOURCE_DIR="$PWD/policies.d"
export QUEUEBASH_CLASS_POLICY_STATEMENT=policyblock-test
export QUEUEBASH_POLICY_BLOCK_ENFORCE=1
queue submit pbtest --class POLICYBLOCKED --reason "audit submit" -- bash -c 'exit 0' >/dev/null
queue run >/dev/null 2>&1 || true
qid="$(queue list --state pol_blocked | awk 'NR==2{print $1}')"
[[ -n "$qid" ]]
queue authorise "$qid" --admin "$(id -un)" >/dev/null
queue resubmit "$qid" >/dev/null
queue run >/dev/null 2>&1 || true
queue list --state all | grep -q ' pol_blocked '
queue list --state all | grep -q ' done '
# A fresh resubmission of the same command should find the on-file command-bound authorisation.
queue submit pbtest2 --class POLICYBLOCKED -- bash -c 'exit 0' >/dev/null
queue run >/dev/null 2>&1 || true
queue list --state all | grep -q 'pbtest2'
! queue list --state pol_blocked | grep -q 'pbtest2'
echo '[PASS] pol_blocked jobs can be resubmitted and on-file command authorisations are reused'
