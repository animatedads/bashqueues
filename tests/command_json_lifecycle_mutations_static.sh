#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
qb="$repo_root/queuebash.sh"

for token in \
  'schema":"queuebash.command_result.v1' \
  'cancel|kill)' \
  'pause|hold|delete|del|rm|remove)' \
  'priority|prio|dynamic-prio)' \
  'unpause|resume|release)' \
  'clear)' \
  '_queue_command_error_json' \
  '_queue_json_bool'
do
  grep -q "$token" "$qb" || { echo "missing lifecycle JSON token: $token" >&2; exit 1; }
done

grep -q -- '--json|-j) json_output=1' "$qb" || { echo "missing --json parser for lifecycle commands" >&2; exit 1; }
grep -q '"command":"%s","target":"%s","queue_root"' "$qb" || { echo "missing command result JSON envelope" >&2; exit 1; }

echo "PASS command_json_lifecycle_mutations_static"
