#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
qb="$repo_root/queuebash.sh"

for token in \
  'undelete|undel|restore)' \
  'resubmit|retry)' \
  'restore_state' \
  'new_qid' \
  'would_resubmit' \
  'no_resubmittable_state' \
  'Usage: queue undelete <qid-or-exact-job-name> [pending|done|failed|cancelled] [--force] [--dryrun] [--json]' \
  'Usage: queue resubmit <qid-or-exact-job-name> [--force] [--dryrun] [--note TEXT] [--json]'
do
  grep -Fq "$token" "$qb" || { echo "missing restore/resubmit JSON token: $token" >&2; exit 1; }
done

# These two recovery commands are lifecycle mutations and must share the common envelope.
grep -Fq 'schema":"queuebash.command_result.v1","ok":true,"command":"%s","target":"%s","queue_root"' "$qb" || { echo "missing command_result envelope" >&2; exit 1; }

echo "PASS command_json_lifecycle_restore_resubmit_static"
