#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source "$repo_root/queuebash.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
mkdir -p "$QUEUEBASH_ROOT"

lines="${1:-1000000}"
echo "Running logstorm stress with $lines lines"

queue submit million_line_logstorm --max-log-size 500M -- "$repo_root/tests/line_storm.sh" "$lines" >/dev/null
queue run >/dev/null

job="$(grep -l '^JOB_NAME=million_line_logstorm$' "$QUEUEBASH_ROOT"/done/*.job)"
id="$(basename "$job" .job)"
log="$QUEUEBASH_ROOT/logs/$id.log"

grep -q "LINE $lines stdout" "$log"
grep -q '^LOG_BYTES=' "$job"

echo "bashqueues logstorm stress: OK ($lines lines)"
