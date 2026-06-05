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
json_assert='import json,sys; data=json.load(sys.stdin); assert data["schema"]=="queuebash.command_result.v1"; assert data["ok"] is True; assert data["changed"] >= 1; print(data["command"])'

qid="$(queue submit lifecycle-priority --json -- echo priority | python3 -c "$qid_from_submit")"
queue priority "$qid" 3 --json | python3 -c "$json_assert" | grep -qx priority

qid_pause="$(queue submit lifecycle-pause --json -- echo pause | python3 -c "$qid_from_submit")"
queue pause "$qid_pause" --json | python3 -c "$json_assert" | grep -qx pause
queue unpause "$qid_pause" --json | python3 -c "$json_assert" | grep -qx unpause
queue delete "$qid_pause" --json | python3 -c "$json_assert" | grep -qx delete
queue clear deleted --dryrun --json | python3 -m json.tool >/dev/null

qid2="$(queue submit lifecycle-two --json -- echo two | python3 -c "$qid_from_submit")"
queue cancel "$qid2" --json | python3 -c "$json_assert" | grep -qx cancel

queue cancel definitely-missing --json >"$root/missing.json" && { echo "missing cancel unexpectedly succeeded" >&2; exit 1; }
python3 - <<'PY' "$root/missing.json"
import json, sys
with open(sys.argv[1]) as fh:
    data=json.load(fh)
assert data["schema"] == "queuebash.command_result.v1"
assert data["ok"] is False
assert data["error"]["code"] == "no_match"
PY

echo "PASS command_json_lifecycle_mutations_smoke"
