#!/usr/bin/env bash
set -euo pipefail
fail() { echo "FAIL: $*" >&2; exit 1; }
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
trap 'rm -rf "$QUEUEBASH_ROOT"' EXIT
# shellcheck source=/dev/null
source ./queuebash.sh
out="$(mktemp)"
queue --json help > "$out"
python3 - "$out" <<'PY'
import json, sys
obj=json.load(open(sys.argv[1]))
assert obj["schema"] == "queuebash.command_catalog.v1", obj
commands=set(obj.get("commands") or [])
required={
    "health","events","policies","pids","metrics","hooks",
    "cancel","delete","pause","unpause","priority","clear","restore","resubmit",
    "clean-logs","compress-logs","backup","reevaluate",
}
missing=sorted(required-commands)
assert not missing, missing
assert obj.get("global_json") is True, obj
PY
rm -f "$out"
echo "command catalog JSON discoverability smoke checks: OK"
