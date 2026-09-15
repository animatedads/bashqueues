#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/root" QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh
_queue_init
n=40
for i in $(seq 1 "$n"); do
  queue submit "rapid_$i" -- /bin/true >/dev/null &
done
wait
count="$(find "$QUEUEBASH_ROOT/pending" -type f -name '*.job' | wc -l | tr -d ' ')"
[[ "$count" == "$n" ]]
ids="$(find "$QUEUEBASH_ROOT/pending" -type f -name '*.job' -printf '%f\n' | sed 's/\.job$//' | sort | uniq | wc -l | tr -d ' ')"
[[ "$ids" == "$n" ]]
