#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

DOC="docs/QUEUE_COMMAND_CONTRACT.md"
QB="queuebash.sh"
needles=(
  'Human output is the default'
  '`--json` output is parseable JSON on stdout'
  'queuebash.error.v1'
  'queue <domain> <verb>'
  'Legacy command aliases remain supported'
  'queuebash.env.list.v1'
  'queuebash.version.v1'
  'queuebash.selected_user.v1'
  'queuebash.queue_users.v1'
  'queuebash.draft.list.v1'
  'queuebash.draft.show.v1'
  'queuebash.draft.create.v1'
  'queuebash.draft.state.v1'
  'queuebash.acl.help.v1'
  'queuebash.acl.operations.v1'
  'queuebash.show.v1'
  'queuebash.history.v1'
  'queuebash.tail.v1'
)
for needle in "${needles[@]}"; do
  grep -R -F -- "$needle" "$DOC" "$QB" >/dev/null
done

for needle in \
  '_queue_acl_help_json' \
  '_queue_acl_operations_json' \
  'version|--version|-V)' \
  'queue-user|queue-owner)' \
  'queue-users)'; do
  grep -F -- "$needle" "$QB" >/dev/null
done

echo "queue command contract static checks passed"
