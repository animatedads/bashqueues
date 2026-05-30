#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "FAIL: $*" >&2; exit 1; }

[[ -f queuebash.sh ]] || fail 'run from repository root'
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
scratch_root="$(mktemp -d "${TMPDIR:-/tmp}/queuebash-scratch-life.XXXXXX")"
trap 'rm -rf "$scratch_root"' EXIT
export QUEUEBASH_ROOT="$scratch_root/root"
export QUEUEBASH_DEV_SCRATCHPAD="$scratch_root/scratchpad.json"
# shellcheck disable=SC1091
source ./queuebash.sh
qds(){ _queue_dev_scratchpad_command "$@"; }

qds init --project lifecycle --json > /dev/null
qds add --kind task --authority team_leader --text 'old duplicate task' --tag duplicate --json > "$scratch_root/old.json"
qds add --kind task --authority team_leader --text 'replacement task' --tag current --json > "$scratch_root/new.json"
old_id="$(${QUEUEBASH_PYTHON:-/usr/bin/python3} -c 'import json,sys; print(json.load(open(sys.argv[1]))["item"]["id"])' "$scratch_root/old.json")"
new_id="$(${QUEUEBASH_PYTHON:-/usr/bin/python3} -c 'import json,sys; print(json.load(open(sys.argv[1]))["item"]["id"])' "$scratch_root/new.json")"

qds scratch-wrong 2>/dev/null && fail 'unknown subcommand should fail' || true
qds status set "$new_id" --status in_progress --reason 'started implementation' --authority reviewer --json > "$scratch_root/status.json"
qds supersede "$old_id" --by "$new_id" --reason 'duplicate replaced' --authority team_leader --json > "$scratch_root/supersede.json"
qds list --json > "$scratch_root/list.json"
qds list --all --json > "$scratch_root/list_all.json"
qds next --json > "$scratch_root/next.json"
qds export --json > "$scratch_root/export.json"

${QUEUEBASH_PYTHON:-/usr/bin/python3} - "$scratch_root/status.json" "$scratch_root/supersede.json" "$scratch_root/list.json" "$scratch_root/list_all.json" "$scratch_root/next.json" "$scratch_root/export.json" "$old_id" "$new_id" <<'PY'
import json, sys
status, sup, listing, listing_all, nxt, export = [json.load(open(p)) for p in sys.argv[1:7]]
old_id, new_id = sys.argv[7], sys.argv[8]
assert status['schema'] == 'queuebash.dev_workflow.scratchpad_status.v1'
assert status['item_id'] == new_id and status['new_status'] == 'in_progress'
assert sup['schema'] == 'queuebash.dev_workflow.supersede.v1'
assert sup['item_id'] == old_id and sup['superseded_by'] == new_id and sup['new_status'] == 'superseded'
visible = {i['id']: i for i in listing['items']}
all_visible = {i['id']: i for i in listing_all['items']}
next_ids = {i['id'] for i in nxt['items']}
items = {i['id']: i for i in export['items']}
assert new_id in visible, 'current replacement hidden from default list'
assert old_id not in visible, 'superseded item leaked into default list'
assert old_id in all_visible, 'superseded item missing from --all list'
assert new_id in next_ids, 'current replacement missing from next working set'
assert old_id not in next_ids, 'superseded item leaked into next working set'
assert items[old_id]['status'] == 'superseded'
assert items[old_id]['superseded_by'] == new_id
assert items[old_id]['relations']['superseded_by'] == new_id
assert old_id in items[new_id]['relations']['supersedes']
assert any(i.get('parent_id') == old_id and 'supersede' in i.get('tags', []) for i in export['items']), 'supersede note missing'
assert any(i.get('parent_id') == new_id and 'status-set' in i.get('tags', []) for i in export['items']), 'status note missing'
PY

if qds status set "$new_id" --status bogus --authority reviewer --json > "$scratch_root/bad_status.json" 2>/dev/null; then
  fail 'invalid lifecycle status should fail'
fi
if qds supersede "$new_id" --by "$new_id" --authority reviewer --json > "$scratch_root/self_supersede.json" 2>/dev/null; then
  fail 'self-supersede should fail'
fi
if qds status set "$new_id" --status resolved --authority coding_agent --json > "$scratch_root/low_auth.json" 2>/dev/null; then
  fail 'low-authority status set should fail'
fi

echo 'PASS dev_scratchpad_lifecycle_smoke'
