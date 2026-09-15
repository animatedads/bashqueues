#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

bash -n queuebash.sh || fail 'queuebash syntax failed'
bash -n bin/queue-vcs-probe || fail 'queue-vcs-probe syntax failed'
bash -n bin/queue-vcs-assert || fail 'queue-vcs-assert syntax failed'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
work="$tmp/work"
mkdir -p "$work/CVS"
printf ':pserver:example.invalid:/cvsroot\n' > "$work/CVS/Root"
printf 'TPROD_1989\n' > "$work/CVS/Tag"

export QUEUEBASH_ROOT="$PWD"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export PATH="$PWD/bin:$PATH"
# shellcheck disable=SC1091
. ./queuebash.sh >/dev/null

out="$(queue vcs assert "$work" --json --type cvs --timeout 1 --require-identity PROD_1989)"
python3 -c 'import json,sys; obj=json.loads(sys.stdin.read()); assert obj["schema"]=="queuebash.vcs.assert.v1", obj; assert obj["read_only"] is True, obj; assert obj["matched"] is True, obj; assert obj["type"]=="cvs", obj; assert obj["identity"]=="PROD_1989", obj; assert obj["checks"][0]["field"]=="identity", obj' <<<"$out"

if queue vcs assert "$work" --json --type cvs --timeout 1 --require-identity WRONG >/tmp/bq-vcs-assert-negative.json 2>/tmp/bq-vcs-assert-negative.err; then
  fail 'negative assert unexpectedly passed'
fi
python3 -c 'import json,sys; obj=json.load(open(sys.argv[1])); assert obj["matched"] is False, obj; assert obj["failures"], obj' /tmp/bq-vcs-assert-negative.json

echo '[PASS] VCS assert command JSON smoke contract works'
