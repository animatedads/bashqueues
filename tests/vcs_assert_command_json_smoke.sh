#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "[FAIL] $*" >&2; exit 1; }

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/vcs-assert.XXXXXX")"
trap 'rm -rf "$QUEUEBASH_ROOT" "$tmp"' EXIT
source ./queuebash.sh

work="$tmp/work"
mkdir -p "$work/CVS"
printf ':pserver:example.invalid:/cvsroot\n' > "$work/CVS/Root"
printf 'TPROD_1989\n' > "$work/CVS/Tag"

# Exercise the queue facade and helper path using CVS metadata only. This stays
# offline even on machines without a CVS client and remains read-only.
out="$(queue vcs assert "$work" --json --type cvs --timeout 1 --require-identity PROD_1989)"
python3 -c 'import json,sys; obj=json.loads(sys.stdin.read()); assert obj["schema"]=="queuebash.vcs.assert.v1", obj; assert obj["read_only"] is True, obj; assert obj["matched"] is True, obj; assert obj["type"]=="cvs", obj; assert obj["identity"]=="PROD_1989", obj; assert obj["checks"][0]["field"]=="identity", obj' <<<"$out"

echo '[PASS] VCS assert command JSON smoke contract works'
