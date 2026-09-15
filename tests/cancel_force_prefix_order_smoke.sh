#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/root" QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh
_queue_init
qid="$(queue submit cancel_order --json -- /bin/true | python3 -c 'import sys,json; print(json.load(sys.stdin)["qid"])')"
queue cancel --force "$qid" --json | python3 -c 'import sys,json; j=json.load(sys.stdin); assert j["ok"] and j["changed"]==1'
[[ -f "$QUEUEBASH_ROOT/cancelled/$qid.job" ]]
