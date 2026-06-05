#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$root"
mkdir -p "$root"
grep '^QUEUEBASH_VERSION=' "$repo_root/queuebash.sh" | head -1 | cut -d'"' -f2 > "$root/.queuebash_bundled_install_version"
# shellcheck source=/dev/null
source "$repo_root/queuebash.sh"

qid_from_submit='import json,sys; print(json.load(sys.stdin)["qid"])'
check_ok='import json,sys; d=json.load(sys.stdin); assert d["schema"]=="queuebash.command_result.v1"; assert d["ok"] is True; assert d["changed"] >= 1; print(d["command"])'

qid="$(queue submit restore-json --json -- echo restore | python3 -c "$qid_from_submit")"
queue delete "$qid" --json | python3 -c "$check_ok" | grep -qx delete
queue undelete "$qid" failed --json >"$root/undelete.json"
python3 - <<'PY' "$root/undelete.json"
import json,sys
with open(sys.argv[1]) as fh:
    d=json.load(fh)
assert d["schema"] == "queuebash.command_result.v1"
assert d["ok"] is True
assert d["command"] == "undelete"
assert d["restore_state"] == "failed"
assert d["changed"] == 1
assert d["jobs"][0]["to_state"] == "failed"
print(d["command"])
PY

queue resubmit "$qid" --dryrun --json >"$root/resubmit-dryrun.json"
python3 - <<'PY' "$root/resubmit-dryrun.json"
import json,sys
with open(sys.argv[1]) as fh:
    d=json.load(fh)
assert d["schema"] == "queuebash.command_result.v1"
assert d["ok"] is True
assert d["command"] == "resubmit"
assert d["dryrun"] is True
assert d["changed"] == 0
assert d["jobs"][0]["action"] == "would_resubmit"
assert d["jobs"][0]["new_qid"]
print(d["command"])
PY

queue resubmit "$qid" --json >"$root/resubmit.json"
python3 - <<'PY' "$root/resubmit.json"
import json,sys
with open(sys.argv[1]) as fh:
    d=json.load(fh)
assert d["schema"] == "queuebash.command_result.v1"
assert d["ok"] is True
assert d["command"] == "resubmit"
assert d["dryrun"] is False
assert d["changed"] == 1
assert d["jobs"][0]["action"] == "resubmitted"
assert d["jobs"][0]["new_qid"]
print(d["command"])
PY

queue undelete definitely-missing --json >"$root/missing.json" && { echo "missing undelete unexpectedly succeeded" >&2; exit 1; }
python3 - <<'PY' "$root/missing.json"
import json,sys
with open(sys.argv[1]) as fh:
    d=json.load(fh)
assert d["schema"] == "queuebash.command_result.v1"
assert d["ok"] is False
assert d["error"]["code"] == "no_match"
PY

echo "PASS command_json_lifecycle_restore_resubmit_smoke"
