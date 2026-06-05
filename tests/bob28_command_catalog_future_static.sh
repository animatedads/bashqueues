#!/usr/bin/env bash
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

bash -n queuebash.sh

grep -q 'queuebash.command_catalog.v1' queuebash.sh || fail "command catalog schema missing"
grep -q 'global_json":true' queuebash.sh || fail "global json marker missing"
grep -q '"remote-admin"' queuebash.sh || fail "remote-admin missing from JSON catalog"
grep -q '"queue-user"' queuebash.sh || fail "queue-user missing from JSON catalog"
grep -q '"vcs"' queuebash.sh || fail "vcs missing from JSON catalog"
grep -q '"dev"' queuebash.sh || fail "dev missing from JSON catalog"
! grep -q 'QUEUEBASH_VERSION="0.18.119"' tests/bob28_direct_execution_and_global_json_static.sh || fail "direct/global JSON static test has stale exact version pin"
! grep -q 'QUEUEBASH_VERSION="0.18.119"' tests/bob28_global_json_passthrough_static.sh || fail "passthrough static test has stale exact version pin"

echo "bob28 command catalog future static checks: OK"
