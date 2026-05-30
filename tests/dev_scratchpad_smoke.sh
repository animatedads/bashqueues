#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "FAIL: $*" >&2; exit 1; }

[[ -f queuebash.sh ]] || fail "run from repository root"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
scratch_root="$(mktemp -d "${TMPDIR:-/tmp}/queuebash-scratch-smoke.XXXXXX")"
trap 'rm -rf "$scratch_root"' EXIT
export QUEUEBASH_ROOT="$scratch_root/root"
export QUEUEBASH_DEV_SCRATCHPAD="$scratch_root/scratchpad.json"
# shellcheck disable=SC1091
source ./queuebash.sh
qds(){ _queue_dev_scratchpad_command "$@"; }

qds init --project smoke --json > "$scratch_root/init.json"
${QUEUEBASH_PYTHON:-/usr/bin/python3} -c 'import json,sys,pathlib; j=json.load(open(sys.argv[1])); assert j["schema"]=="queuebash.dev_scratchpad.v1"; assert pathlib.Path(sys.argv[2]).exists()' "$scratch_root/init.json" "$QUEUEBASH_DEV_SCRATCHPAD"

qds import --from-tree . --json > "$scratch_root/import.json"
${QUEUEBASH_PYTHON:-/usr/bin/python3} -c 'import json,sys; ledger=json.load(open(sys.argv[1])); assert any(i["authority"]["type"]=="source_tree" and i["authority"]["confidence"]=="observed" for i in ledger["items"]); assert any("QUEUEBASH_VERSION=" in i["text"] for i in ledger["items"])' "$QUEUEBASH_DEV_SCRATCHPAD"

contract_json="$scratch_root/contract.json"
qds add --kind contract --authority architect --text 'Do not refactor queue().' --tag safety --json > "$contract_json"
task_json="$scratch_root/task.json"
qds task --text 'Implement scratchpad ledger only' --authority team_leader --json > "$task_json"
task_id="$(${QUEUEBASH_PYTHON:-/usr/bin/python3} -c 'import json,sys; print(json.load(open(sys.argv[1]))["item"]["id"])' "$task_json")"

qds attempt "$task_id" --note 'first attempt' --json > /dev/null
qds attempt "$task_id" --note 'latest attempt' --json > /dev/null
qds bump-fail "$task_id" --json > "$scratch_root/bump.json"

printf 'line one\nline two\nvery long raw log should be pointed to and tailed\n' > "$scratch_root/raw.log"
printf '{"schema":"queuebash.dev_test_result.v1","status":"failed"}\n' > "$scratch_root/result.json"
qds evidence "$task_id" --json-file "$scratch_root/result.json" --summary 'manual future test result evidence' --raw-log "$scratch_root/raw.log" --verdict failed --json > "$scratch_root/evidence.json"

qds list --json > "$scratch_root/list.json"
qds list --kind task --json > "$scratch_root/list_tasks.json"
list_count="$(${QUEUEBASH_PYTHON:-/usr/bin/python3} -c 'import json,sys; j=json.load(open(sys.argv[1])); assert j["status"]=="ok"; assert j["count"] >= 1; print(j["count"])' "$scratch_root/list.json")"
[[ "$list_count" -ge 1 ]] || fail 'scratchpad list returned no items'

qds add --kind task --authority coding_agent --text 'temporary done task' --json > "$scratch_root/done_task.json"
done_id="$(${QUEUEBASH_PYTHON:-/usr/bin/python3} -c 'import json,sys; print(json.load(open(sys.argv[1]))["item"]["id"])' "$scratch_root/done_task.json")"
qds done "$done_id" --note 'complete' --json > /dev/null
qds add --kind task --authority reviewer --text 'temporary delete task' --json > "$scratch_root/delete_task.json"
delete_id="$(${QUEUEBASH_PYTHON:-/usr/bin/python3} -c 'import json,sys; print(json.load(open(sys.argv[1]))["item"]["id"])' "$scratch_root/delete_task.json")"
qds delete "$delete_id" --authority reviewer --note 'soft delete smoke item' --json > "$scratch_root/delete.json"
qds next --json > "$scratch_root/next.json"
qds export --json > "$scratch_root/export.json"
qds explain "$task_id" > "$scratch_root/explain.txt"

${QUEUEBASH_PYTHON:-/usr/bin/python3} -c 'import json,sys; n=json.load(open(sys.argv[1])); e=json.load(open(sys.argv[2])); task_id=sys.argv[3]; done_id=sys.argv[4]; delete_id=sys.argv[6]; ids=[i["id"] for i in n["items"]]; assert n["schema"]=="queuebash.dev_scratchpad_working_set.v1"; assert e["schema"]=="queuebash.dev_scratchpad.v1"; assert task_id in ids, "active task missing from next"; assert done_id not in ids, "done task leaked into next"; assert delete_id not in ids, "removed task leaked into next"; assert any(i["kind"]=="contract" for i in n["items"]), "active contract missing from next"; assert n["counters"]["failure"] >= 1, "failure counter missing from next"; assert len([i for i in n["items"] if i["kind"]=="attempt"]) <= 2, "attempts were not compressed"; assert len(e["items"]) > len(n["items"]), "export should include full ledger"; assert "Scratchpad item:" in open(sys.argv[5]).read(), "explain is not useful human output"; assert any(i.get("json_schema")=="queuebash.dev_test_result.v1" for i in e["items"]), "manual future test result evidence not stored"; assert any(i.get("raw_log_path") for i in e["items"]), "raw log pointer missing"; assert any(i.get("id")==delete_id and i.get("status")=="removed" for i in e["items"]), "delete did not mark item removed"' "$scratch_root/next.json" "$scratch_root/export.json" "$task_id" "$done_id" "$scratch_root/explain.txt" "$delete_id"

printf '{bad json' > "$QUEUEBASH_DEV_SCRATCHPAD"
if qds export --json > "$scratch_root/bad.out" 2> "$scratch_root/bad.err"; then
  fail 'malformed scratchpad should fail clearly'
fi
cat "$scratch_root/bad.err" >> "$scratch_root/bad.out"
grep -q 'malformed scratchpad' "$scratch_root/bad.out" || fail 'malformed scratchpad JSON error missing'

echo 'PASS dev_scratchpad_smoke'
